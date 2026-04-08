import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query private var folders: [Folder]

    private enum Scope: String, CaseIterable, Identifiable { case all = "All", folders = "Folders"; var id: String { rawValue } }
    @State private var scope: Scope = .all
    @State private var selectedFolder: Folder?

    @State private var selection: Item?
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteOffsets: IndexSet? = nil
    @State private var showListDeleteConfirm = false
    @State private var draftText: String = ""
    @State private var searchText: String = ""
    @State private var showFolderDeleteConfirm = false
    @State private var pendingFolderDeleteOffsets: IndexSet? = nil

    private var scopedItems: [Item] {
        switch scope {
        case .all:
            return items.sorted { $0.pinned && !$1.pinned }
        case .folders:
            if let folder = selectedFolder {
                return items
                    .filter { $0.folder?.persistentModelID == folder.persistentModelID }
                    .sorted { $0.pinned && !$1.pinned }
            } else {
                return []
            }
        }
    }

    private var filteredItems: [Item] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return scopedItems
        }
        let query = searchText.lowercased()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return scopedItems.filter { item in
            let normalizedText = item.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let textPrefixMatch = normalizedText.hasPrefix(query)
            let dateString = dateFormatter.string(from: item.timestamp).lowercased()
            let datePrefixMatch = dateString.hasPrefix(query)
            let folderName = (item.folder?.name ?? "").lowercased()
            let folderPrefixMatch = folderName.hasPrefix(query)
            return textPrefixMatch || datePrefixMatch || folderPrefixMatch
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if scope == .folders {
                    List(selection: $selectedFolder) {
                        ForEach(folders) { folder in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                TextField("Folder Name", text: Binding(
                                    get: { folder.name },
                                    set: { newValue in
                                        folder.name = newValue
                                        try? modelContext.save()
                                    }
                                ))
                                .textFieldStyle(.plain)
                            }
                            .tag(folder)
                        }
                        .onDelete { offsets in
                            pendingFolderDeleteOffsets = offsets
                            showFolderDeleteConfirm = true
                        }
                    }
                    .frame(minHeight: 120)
                }

                Divider()

                ScrollView {
                    if filteredItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text("No Notes")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredItems) { item in
                                NoteCard(item: item) {
                                    selection = item
                                    draftText = item.text
                                }
                                .contextMenu {
                                    Button {
                                        item.pinned.toggle()
                                        try? modelContext.save()
                                    } label: {
                                        Label(item.pinned ? "Unpin" : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        if let idx = filteredItems.firstIndex(where: { $0.id == item.id }) {
                                            pendingDeleteOffsets = IndexSet(integer: idx)
                                            showListDeleteConfirm = true
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .onAppear {
                if selection == nil { selection = filteredItems.first }
                if let sel = selection { draftText = sel.text }
                scope = .all
                selectedFolder = nil
            }
            .onChange(of: items) { _, newItems in
                if let current = selection, !newItems.contains(where: { $0.id == current.id }) {
                    selection = newItems.first
                } else if selection == nil {
                    selection = newItems.first
                }
            }
            .onChange(of: scope) { _, _ in
                if selection == nil || !scopedItems.contains(where: { $0.id == selection?.id }) {
                    selection = filteredItems.first
                }
            }
            .onChange(of: selectedFolder) { _, _ in
                if selection == nil || !scopedItems.contains(where: { $0.id == selection?.id }) {
                    selection = filteredItems.first
                }
            }
            .onChange(of: searchText) { _, _ in
                if let sel = selection, !filteredItems.contains(where: { $0.id == sel.id }) {
                    selection = filteredItems.first
                } else if selection == nil {
                    selection = filteredItems.first
                }
            }
            .onChange(of: selection) { _, newSel in
                draftText = newSel?.text ?? ""
            }
            .confirmationDialog("Delete note?", isPresented: $showListDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        deleteItems(offsets: offsets)
                        pendingDeleteOffsets = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeleteOffsets = nil }
            }
            .confirmationDialog("Delete selected folder(s)?", isPresented: $showFolderDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Folder (Keep Notes)", role: .destructive) {
                    if let offsets = pendingFolderDeleteOffsets {
                        deleteFolders(at: offsets)
                        pendingFolderDeleteOffsets = nil
                    }
                }
                Button("Delete Folder and Notes", role: .destructive) {
                    if let offsets = pendingFolderDeleteOffsets {
                        deleteFoldersAndNotes(at: offsets)
                        pendingFolderDeleteOffsets = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingFolderDeleteOffsets = nil }
            }
            .searchable(text: $searchText, placement: .automatic, prompt: "Search notes")
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 320, ideal: 440)
#endif
            .navigationTitle("Notes")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Image(systemName: "plus")
                    }
                    .help("Add Note")
                }
                ToolbarItem {
                    if scope == .folders {
                        Button {
                            withAnimation {
                                let newFolder = Folder(name: "Untitled Folder")
                                modelContext.insert(newFolder)
                                selectedFolder = newFolder
                            }
                        } label: { Label("Add Folder", systemImage: "folder.badge.plus") }
                    }
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if scope == .folders, let selFolder = selectedFolder, let idx = folders.firstIndex(where: { $0.id == selFolder.id }) {
                        Button(role: .destructive) {
                            pendingFolderDeleteOffsets = IndexSet(integer: idx)
                            showFolderDeleteConfirm = true
                        } label: { Label("Delete Folder", systemImage: "trash") }
                    }
                }
#else
                ToolbarItem {
                    if scope == .folders, let selFolder = selectedFolder, let idx = folders.firstIndex(where: { $0.id == selFolder.id }) {
                        Button(role: .destructive) {
                            pendingFolderDeleteOffsets = IndexSet(integer: idx)
                            showFolderDeleteConfirm = true
                        } label: { Label("Delete Folder", systemImage: "trash") }
                    }
                }
#endif
            }
        } detail: {
            Group {
                if let selected = selection {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selected.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $draftText)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                            .onChange(of: draftText) { _, newValue in
                                updateSelectedText(with: newValue)
                            }
                        Spacer(minLength: 0)
                    }
                    .padding()
                    .navigationTitle("Note")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                if let selected = selection {
                                    selected.pinned.toggle()
                                    try? modelContext.save()
                                }
                            } label: {
                                Label(
                                    selection?.pinned == true ? "Unpin" : "Pin",
                                    systemImage: selection?.pinned == true ? "pin.slash" : "pin"
                                )
                            }
                            .disabled(selection == nil)
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(selection == nil)
                            .confirmationDialog("Delete this note?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button("Delete", role: .destructive) { performDeleteSelected() }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }
                } else {
                    Text("Select a note")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func performDeleteSelected() {
        guard let selected = selection, let index = items.firstIndex(where: { $0.id == selected.id }) else { return }
        withAnimation {
            modelContext.delete(items[index])
            selection = nil
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            if scope == .folders, let folder = selectedFolder {
                newItem.folder = folder
            }
            modelContext.insert(newItem)
            selection = newItem
            searchText = ""
            draftText = newItem.text
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            var deletedSelected = false
            for index in offsets {
                if let sel = selection, filteredItems[index].id == sel.id {
                    deletedSelected = true
                }
                modelContext.delete(filteredItems[index])
            }
            if deletedSelected { selection = filteredItems.first }
        }
    }

    private func updateSelectedText(with newValue: String) {
        guard let selected = selection else { return }
        selected.text = newValue
        try? modelContext.save()
    }

    private func deleteFolders(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let folder = folders[index]
                let affected = items.filter { $0.folder?.persistentModelID == folder.persistentModelID }
                for item in affected { item.folder = nil }
                modelContext.delete(folder)
            }
            if let selFolder = selectedFolder, !folders.contains(where: { $0.id == selFolder.id }) {
                selectedFolder = nil
            }
        }
    }

    private func deleteFoldersAndNotes(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let folder = folders[index]
                let toDelete = items.filter { $0.folder?.persistentModelID == folder.persistentModelID }
                for item in toDelete { modelContext.delete(item) }
                modelContext.delete(folder)
            }
            if let selFolder = selectedFolder, !folders.contains(where: { $0.id == selFolder.id }) {
                selectedFolder = nil
            }
            if let current = selection, !items.contains(where: { $0.id == current.id }) {
                selection = filteredItems.first
            }
        }
    }
}

// MARK: - Note Card

struct NoteCard: View {
    let item: Item
    let onTap: () -> Void

    private var preview: String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Empty note" : trimmed
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text(preview)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)

                Spacer(minLength: 0)

                Divider()
                    .opacity(0.4)

                HStack {
                    Text(item.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 180)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

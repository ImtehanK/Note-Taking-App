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
            return items
        case .folders:
            if let folder = selectedFolder {
                return items.filter { $0.folder?.persistentModelID == folder.persistentModelID }
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
            // Normalize note text by trimming leading whitespace/newlines before prefix check
            let normalizedText = item.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let textPrefixMatch = normalizedText.hasPrefix(query)

            let dateString = dateFormatter.string(from: item.timestamp).lowercased()
            let datePrefixMatch = dateString.hasPrefix(query)

            let folderName = (item.folder?.name ?? "").lowercased()
            let folderPrefixMatch = folderName.hasPrefix(query)

            return textPrefixMatch || datePrefixMatch || folderPrefixMatch
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 8) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)

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

                List(selection: $selection) {
                    ForEach(filteredItems) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                .font(.body)
                        }
                        .tag(item)
                    }
                    .onDelete { offsets in
                        pendingDeleteOffsets = offsets
                        showListDeleteConfirm = true
                    }
                }
            }
            .onAppear {
                if selection == nil {
                    selection = filteredItems.first
                }
                if let sel = selection {
                    draftText = sel.text
                }
                scope = .all
                selectedFolder = nil
            }
            .onChange(of: items) { _, newItems in
                if let current = selection, !newItems.contains(where: { $0.id == current.id }) {
                    // Selected item was removed; pick the first available
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
                let newText = newSel?.text ?? ""
                draftText = newText
            }
            .confirmationDialog("Delete selected note(s)?", isPresented: $showListDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        deleteItems(offsets: offsets)
                        pendingDeleteOffsets = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteOffsets = nil
                }
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
                Button("Cancel", role: .cancel) {
                    pendingFolderDeleteOffsets = nil
                }
            }
            .searchable(text: $searchText, placement: .automatic, prompt: "Search notes")
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
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
                        } label: {
                            Label("Delete Folder", systemImage: "trash")
                        }
                        .help("Delete selected folder")
                    }
                }
#else
                ToolbarItem {
                    if scope == .folders, let selFolder = selectedFolder, let idx = folders.firstIndex(where: { $0.id == selFolder.id }) {
                        Button(role: .destructive) {
                            pendingFolderDeleteOffsets = IndexSet(integer: idx)
                            showFolderDeleteConfirm = true
                        } label: {
                            Label("Delete Folder", systemImage: "trash")
                        }
                        .help("Delete selected folder")
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
                    .navigationTitle("Note")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(role: .destructive) {
                                deleteSelected()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(selection == nil)
                            .confirmationDialog("Delete this note?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button("Delete", role: .destructive) {
                                    performDeleteSelected()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }
                } else {
                    Text("Select an item")
                }
            }
        }
    }

    private func deleteSelected() {
        showDeleteConfirm = true
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
                if let sel = selection, items[index].id == sel.id {
                    deletedSelected = true
                }
                modelContext.delete(items[index])
            }
            if deletedSelected {
                selection = filteredItems.first
            }
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
                // Clear folder assignment from items in this folder
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
                // Delete all items in this folder
                let toDelete = items.filter { $0.folder?.persistentModelID == folder.persistentModelID }
                for item in toDelete { modelContext.delete(item) }
                // Delete the folder itself
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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

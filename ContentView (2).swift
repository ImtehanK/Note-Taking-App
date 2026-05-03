import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query private var folders: [Folder]

    private enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case folders = "Folders"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .all
    @State private var selectedFolder: Folder?

    @State private var selection: Item?
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteOffsets: IndexSet? = nil
    @State private var showListDeleteConfirm = false
    @State private var draftText = AttributedString("")
    @State private var searchText: String = ""
    @State private var showFolderDeleteConfirm = false
    @State private var pendingFolderDeleteOffsets: IndexSet? = nil

    @AppStorage("recentSearches") private var recentSearchesData: Data = Data()
    @State private var recentSearches: [String] = []

    @StateObject private var aiViewModel = AIViewModel()

    private var scopedItems: [Item] {
        switch scope {
        case .all:
            return items.sorted {
                if $0.pinned != $1.pinned {
                    return $0.pinned && !$1.pinned
                }
                return $0.timestamp > $1.timestamp
            }
        case .folders:
            if let folder = selectedFolder {
                return items
                    .filter { $0.folder?.persistentModelID == folder.persistentModelID }
                    .sorted {
                        if $0.pinned != $1.pinned {
                            return $0.pinned && !$1.pinned
                        }
                        return $0.timestamp > $1.timestamp
                    }
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
            let normalizedText = String(item.text.characters)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let textMatch = fuzzyContains(normalizedText, query: query)

            let dateString = dateFormatter.string(from: item.timestamp)
            let dateMatch = fuzzyContains(dateString, query: query)

            let folderName = item.folder?.name ?? ""
            let folderMatch = fuzzyContains(folderName, query: query)

            return textMatch || dateMatch || folderMatch
        }
    }

    private var searchPrompt: String {
        if !searchText.isEmpty && filteredItems.isEmpty {
            return scope == .folders ? "No results · Try searching all notes" : "No results · Refine your search"
        }

        switch scope {
        case .all:
            return "Search all notes"
        case .folders:
            if selectedFolder == nil {
                return "Select a folder to search"
            }

            if let name = selectedFolder?.name, !name.isEmpty {
                return "Search notes in \"\(name)\""
            } else {
                return "Search notes in selected folder"
            }
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
                loadRecentSearches()

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
                draftText = newSel?.text ?? AttributedString("")
            }
            .confirmationDialog("Delete note?", isPresented: $showListDeleteConfirm, titleVisibility: .visible) {
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
            .searchable(text: $searchText, placement: .automatic, prompt: Text(searchPrompt)) {
                if searchText.isEmpty {
                    if recentSearches.isEmpty {
                        Text("No recent searches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentSearches, id: \.self) { term in
                            HStack {
                                Text(term)
                                    .searchCompletion(term)

                                Spacer()

                                Button {
                                    removeRecentSearch(term)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button(role: .destructive) {
                            clearAllRecentSearches()
                        } label: {
                            Label("Clear Recent Searches", systemImage: "trash")
                        }
                    }
                }

                if scope == .folders, selectedFolder == nil {
                    Text("Select a folder to search")
                        .foregroundStyle(.secondary)
                }

                if !searchText.isEmpty && filteredItems.isEmpty {
                    if scope == .folders {
                        Button("Search all notes") {
                            scope = .all
                        }
                    }

                    Button("Clear search") {
                        searchText = ""
                    }
                }
            }
            .onSubmit(of: .search) {
                addRecentSearch(searchText)
            }
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
                        } label: {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                        }
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
                    }
                }
#endif
            }
        } detail: {
            Group {
                if let selected = selection {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selected.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $draftText)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                            .frame(minHeight: 200)
                            .onChange(of: draftText) { _, newValue in
                                updateSelectedText(with: newValue)
                            }

                        HStack(spacing: 12) {
                            Button {
                                aiViewModel.sendMessage(text: String(draftText.characters))
                            } label: {
                                HStack {
                                    Image(systemName: "scissors")
                                    Text("Summarize")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }
                            .disabled(String(draftText.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                aiViewModel.sendMessage()
                                hideKeyboard()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Ask AI")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }

                            Spacer()
                        }

                        Divider()

                        TextField("Enter AI message", text: $aiViewModel.userInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Summary:")
                                    .font(.headline)

                                Text(aiViewModel.summaryResponse)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Divider()

                                Text("AI Response:")
                                    .font(.headline)

                                Text(aiViewModel.searchResponse)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.top)
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
                                Button("Delete", role: .destructive) {
                                    performDeleteSelected()
                                }
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
            if deletedSelected {
                selection = filteredItems.first
            }
        }
    }

    private func updateSelectedText(with newValue: AttributedString) {
        guard let selected = selection else { return }
        selected.text = newValue
        try? modelContext.save()
    }

    private func deleteFolders(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let folder = folders[index]
                let affected = items.filter { $0.folder?.persistentModelID == folder.persistentModelID }
                for item in affected {
                    item.folder = nil
                }
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
                for item in toDelete {
                    modelContext.delete(item)
                }
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

    private func loadRecentSearches() {
        if let decoded = try? JSONDecoder().decode([String].self, from: recentSearchesData) {
            recentSearches = decoded
        }
    }

    private func saveRecentSearches() {
        if let encoded = try? JSONEncoder().encode(recentSearches) {
            recentSearchesData = encoded
        }
    }

    private func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentSearches.removeAll {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }

        recentSearches.insert(trimmed, at: 0)

        if recentSearches.count > 5 {
            recentSearches = Array(recentSearches.prefix(5))
        }

        saveRecentSearches()
    }

    private func removeRecentSearch(_ term: String) {
        recentSearches.removeAll {
            $0.caseInsensitiveCompare(term) == .orderedSame
        }

        saveRecentSearches()
    }

    private func clearAllRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }

    private func levenshtein(_ aStr: String, _ bStr: String) -> Int {
        let a = Array(aStr)
        let b = Array(bStr)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var dist = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m {
            dist[i][0] = i
        }

        for j in 0...n {
            dist[0][j] = j
        }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1

                dist[i][j] = min(
                    dist[i - 1][j] + 1,
                    dist[i][j - 1] + 1,
                    dist[i - 1][j - 1] + cost
                )
            }
        }

        return dist[m][n]
    }

    private func fuzzyContains(_ text: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }

        let t = text.lowercased()

        if t.contains(q) {
            return true
        }

        if q.count <= 3 {
            let window = max(q.count, 1)
            let chars = Array(t)

            if chars.isEmpty {
                return false
            }

            for i in 0..<max(chars.count - window + 1, 0) {
                let slice = String(chars[i..<min(i + window, chars.count)])

                if levenshtein(slice, q) <= 1 {
                    return true
                }
            }
        }

        return false
    }

    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

struct NoteCard: View {
    let item: Item
    let onTap: () -> Void

    private var preview: String {
        let trimmed = String(item.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Empty note" : trimmed
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text(preview)
                    .font(.system(size: 14))
                    .foregroundStyle(item.noteColor.foreground)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(item.noteColor.divider)
                    .frame(height: 1)

                HStack {
                    Text(item.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundStyle(item.noteColor.secondaryForeground)

                    Spacer()

                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(item.noteColor.secondaryForeground)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 180)
            .background(item.noteColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Folder.self], inMemory: true)
}

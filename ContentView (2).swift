import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\Item.timestamp, order: .reverse)
    ])
    private var fetchedItems: [Item]

    private var items: [Item] {
        fetchedItems.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.timestamp > rhs.timestamp
        }
    }

    @State private var selection: Item?
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteOffsets: IndexSet? = nil
    @State private var showListDeleteConfirm = false

    init() {}


    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(items) { item in
                    
                    HStack(alignment: .top, spacing: 8) {
                        if item.pinned {
                            Image(systemName: "pin.fill")
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayTitle(for: item))
                                .lineLimit(1)
                            Text(item.timestamp,
                                 format: Date.FormatStyle(date: .numeric, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(item)
                    
                }
                .onDelete { offsets in
                    pendingDeleteOffsets = offsets
                    showListDeleteConfirm = true
                }
            }
            .onAppear {
                if selection == nil {
                    selection = items.first
                }
            }
            .onChange(of: items) { _, newItems in
                if let current = selection,
                   !newItems.contains(where: { $0.id == current.id }) {
                    selection = newItems.first
                } else if selection == nil {
                    selection = newItems.first
                }
            }
            .confirmationDialog("Delete selected note(s)?",
                                isPresented: $showListDeleteConfirm,
                                titleVisibility: .visible) {
                
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
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            
        } detail: {
            
            Group {
                if let selected = selection {
                    
                    VStack(alignment: .leading, spacing: 16) {
                        
                        Text(selected.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: Binding(
                            get: { selected.text },
                            set: { selected.text = $0 }
                        ))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                        
                        Spacer()
                    }
                    .navigationTitle("Note")
                    .padding()
                    .toolbar {
                        
                        ToolbarItem {
                            Button {
                                togglePin()
                            } label: {
                                Label(
                                    selected.pinned ? "Unpin" : "Pin",
                                    systemImage: selected.pinned ? "pin.slash" : "pin"
                                )
                            }
                        }
                        
                        ToolbarItem(placement: .primaryAction) {
                            Button(role: .destructive) {
                                deleteSelected()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .confirmationDialog("Delete this note?",
                                                isPresented: $showDeleteConfirm) {
                                
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

    private func togglePin() {
        guard let selected = selection else { return }
        
        withAnimation {
            selected.pinned.toggle()
        }
    }

    private func deleteSelected() {
        showDeleteConfirm = true
    }

    private func performDeleteSelected() {
        guard let selected = selection,
              let index = items.firstIndex(where: { $0.id == selected.id }) else { return }
        
        withAnimation {
            modelContext.delete(items[index])
            selection = nil
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date(), text: "")
            modelContext.insert(newItem)
            selection = newItem
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
                selection = items.first
            }
        }
    }

    private func displayTitle(for item: Item) -> String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New note" : String(trimmed.prefix(40))
    }
}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ContentView()
        .modelContainer(container)
}

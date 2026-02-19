//
//  ContentView.swift
//  Note Taking App
//
//  Created by Justin Peralta
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var selection: Item?
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteOffsets: IndexSet? = nil
    @State private var showListDeleteConfirm = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(items) { item in
                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
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
                if let current = selection, !newItems.contains(where: { $0.id == current.id }) {
                    // Selected item was removed; pick the first available
                    selection = newItems.first
                } else if selection == nil {
                    selection = newItems.first
                }
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
                        Text("Item at \(selected.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))")
                        Spacer()
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
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

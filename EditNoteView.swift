import SwiftUI
import SwiftData

struct EditNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $item.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.2))
                    )
            }
            .padding()
            .navigationTitle("Edit Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
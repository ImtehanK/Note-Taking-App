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
                    Toggle ("Bold", isOn: $item.IsBold)
                    HStack {
                        Text("Text Size")
                        Slider(value: $item.textSize, in: 12...36, step: 1)
                        Text("/(Int(item.textSiez))")
                        .frame(width: 35)
                    }

                    Picker("Font", selection: $item.fontName){
                        Text("System").tag("system")
                        Text("Serif").tag("serif")
                        Text("Mono").tag ("mono")
                        Text("Rounded").tag("rounded")
                        Text("Italic").tag("italic")

                    }
                    .pickerStyle(.segment)
                    Picker("Highlight", selection: $item.highlightColorName) {
                        Text("None").tag("clear")
                        Text("Yellow").tag("yellow")
                        Text("Green").tag("green")
                        Text("Blue").tag("blue")
                        Text("Pink").tag("pink")

                    }
                    .pickerStyle(.segmented)

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
 func getFont() -> Font {
        switch item.fontName {
        case "serif":
            return .system(
                size: item.textSize,
                weight: item.isBold ? .bold : .regular,
                design: .serif
            )
        case "mono":
            return .system(
                size: item.textSize,
                weight: item.isBold ? .bold : .regular,
                design: .monospaced
            )
        case "rounded":
            return .system(
                size: item.textSize,
                weight: item.isBold ? .bold : .regular,
                design: .rounded
            )
        case "italic":
            return .system(
                size: item.textSize,
                weight: item.isBold ? .bold : .regular
            ).italic()
        default:
            return .system(
                size: item.textSize,
                weight: item.isBold ? .bold : .regular
            )
        }
    }

    func highlightColor(for name: String) -> Color {
        switch name {
        case "yellow":
            return .yellow
        case "green":
            return .green
        case "blue":
            return .blue
        case "pink":
            return .pink
        default:
            return .clear
        }
    }
}

import SwiftUI
import SwiftData
import Foundation

struct EditNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    @State private var typedTextSize = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("Heading") {
                            item.text += AttributedString("\n# Heading\n")
                        }

                        Menu("Font") {
                            Button("System") { item.fontName = "system" }
                            Button("Serif") { item.fontName = "serif" }
                            Button("Mono") { item.fontName = "mono" }
                            Button("Rounded") { item.fontName = "rounded" }
                            Button("Italic") { item.fontName = "italic" }
                        }

                        HStack(spacing: 4) {
                            Button("-") {
                                if item.textSize > 8 {
                                    item.textSize -= 1
                                    typedTextSize = "\(Int(item.textSize))"
                                }
                            }

                            TextField("Size", text: $typedTextSize)
                                .keyboardType(.numberPad)
                                .frame(width: 45)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    setTypedSize()
                                }

                            Button("+") {
                                if item.textSize < 72 {
                                    item.textSize += 1
                                    typedTextSize = "\(Int(item.textSize))"
                                }
                            }

                            Menu("▼") {
                                Button("8") { setSize(8) }
                                Button("10") { setSize(10) }
                                Button("12") { setSize(12) }
                                Button("14") { setSize(14) }
                                Button("18") { setSize(18) }
                                Button("24") { setSize(24) }
                                Button("36") { setSize(36) }
                                Button("48") { setSize(48) }
                                Button("72") { setSize(72) }
                            }
                        }

                        Button("Bold") {
                            item.isBold.toggle()
                        }

                        Menu("Highlight") {
                            Button("No Highlight") { item.highlightColorName = "clear" }
                            Button("Yellow") { item.highlightColorName = "yellow" }
                            Button("Green") { item.highlightColorName = "green" }
                            Button("Blue") { item.highlightColorName = "blue" }
                            Button("Pink") { item.highlightColorName = "pink" }
                        }

                        Button("Bullet") {
                            item.text += AttributedString("\n• ")
                        }

                        Button("Number") {
                            item.text += AttributedString("\n\(getNextNumber()). ")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                TextEditor(text: $item.text)
                    .font(getFont())
                    .padding(8)
                    .background(highlightColor(for: item.highlightColorName).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.2))
                    )
            }
            .padding()
            .navigationTitle("Edit Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                typedTextSize = "\(Int(item.textSize))"
            }
        }
    }

    func setSize(_ size: Double) {
        item.textSize = size
        typedTextSize = "\(Int(size))"
    }

    func setTypedSize() {
        if let size = Double(typedTextSize), size >= 8, size <= 72 {
            item.textSize = size
        } else {
            typedTextSize = "\(Int(item.textSize))"
        }
    }

    func getFont() -> Font {
        switch item.fontName {
        case "serif":
            return .system(size: item.textSize, weight: item.isBold ? .bold : .regular, design: .serif)
        case "mono":
            return .system(size: item.textSize, weight: item.isBold ? .bold : .regular, design: .monospaced)
        case "rounded":
            return .system(size: item.textSize, weight: item.isBold ? .bold : .regular, design: .rounded)
        case "italic":
            return .system(size: item.textSize, weight: item.isBold ? .bold : .regular).italic()
        default:
            return .system(size: item.textSize, weight: item.isBold ? .bold : .regular)
        }
    }

    func highlightColor(for name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        default: return .clear
        }
    }

    func getNextNumber() -> Int {
        let text = String(item.text.characters)
        let lines = text.components(separatedBy: "\n")
        var count = 0

        for line in lines {
            if line.trimmingCharacters(in: CharacterSet.whitespaces)
                .range(of: #"^\d+\."#, options: String.CompareOptions.regularExpression) != nil {
                count += 1
            }
        }

        return count + 1
    }
}

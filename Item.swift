import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var text: AttributedString = AttributedString("")
    var pinned: Bool = false
    var folder: Folder?
    var colorName: String = NoteColor.allCases.randomElement()!.rawValue

    var fontName: String = "system"
    var textSize: Double = 16
    var isBold: Bool = false
    var highlightColorName: String = "clear"

    init(timestamp: Date, text: AttributedString = AttributedString("")) {
        self.timestamp = timestamp
        self.text = text
        self.pinned = false
        self.colorName = NoteColor.allCases.randomElement()!.rawValue

        self.fontName = "system"
        self.textSize = 16
        self.isBold = false
        self.highlightColorName = "clear"
    }

    var noteColor: NoteColor {
        NoteColor(rawValue: colorName) ?? .sand
    }
}

enum NoteColor: String, CaseIterable {
    case terracotta, sage, sand, clay, moss, dusk

    var displayName: String { rawValue.capitalized }
}

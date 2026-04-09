import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var text: String = ""
    var pinned: Bool = false
    var folder: Folder?
    var colorName: String = NoteColor.allCases.randomElement()!.rawValue

    init(timestamp: Date, text: String = "") {
        self.timestamp = timestamp
        self.text = text
        self.pinned = false
        self.colorName = NoteColor.allCases.randomElement()!.rawValue
    }

    var noteColor: NoteColor {
        NoteColor(rawValue: colorName) ?? .sand
    }
}

enum NoteColor: String, CaseIterable {
    case terracotta, sage, sand, clay, moss, dusk

    var displayName: String { rawValue.capitalized }
}

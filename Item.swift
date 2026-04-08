//
//  Item.swift
//  NoteTakingApp
//
//  Created by Imtehan Kadir on 3/4/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var text: String = ""
    var pinned: Bool = false
    var folder: Folder?
    var isBold: Bool = false
    var textSize: Double = 18
    var highlightColorName: String = "clear"
    var fontName: String = "system"

    init(timestamp: Date, text: String = "",
        pinned: Bool = false,
        folder: Folder? = nil,
        isBold: Bool = false,
        textSize: Double = 18,
        highlightColorName: String = "clear",
        fontName: String = "system") {
        self.timestamp = timestamp
        self.text = text
        self.pinned = false
        self.folder = folder
        self.isBold = isBold
        self.textSize = textSize
        self.highlightColorName = highlightColorName
        self.fontName = fontName
    }
}

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
    
    init(timestamp: Date, text: String = "") {
        self.timestamp = timestamp
        self.text = text
        self.pinned = false
    }
}


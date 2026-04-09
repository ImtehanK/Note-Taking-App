import Foundation
import SwiftData

@Model
final class Folder {
    var name: String
    @Relationship(deleteRule: .nullify, inverse: \Item.folder) var items: [Item] = []

    init(name: String) {
        self.name = name
    }
}

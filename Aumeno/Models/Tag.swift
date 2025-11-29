import Foundation

struct Tag: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var color: String // Hex string, e.g., "#FF0000"

    init(id: String = UUID().uuidString, name: String, color: String) {
        self.id = id
        self.name = name
        self.color = color
    }
}

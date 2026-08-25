import Foundation

struct AppSound: Hashable, Identifiable, Sendable {
    static let none = AppSound(name: "None")

    let name: String
    var id: String { name }
    var isNone: Bool { name == Self.none.name }
}

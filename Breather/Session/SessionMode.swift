import Foundation

enum SessionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var symbolName: String {
        switch self {
        case .focus: "timer"
        case .shortBreak: "cup.and.saucer"
        case .longBreak: "figure.walk"
        }
    }

    var breakMessage: LocalizedStringResource {
        switch self {
        case .focus: "Focus on one thing at a time."
        case .shortBreak: "Look away from the screen."
        case .longBreak: "Stand up, walk around, and rest your eyes."
        }
    }

    var isBreak: Bool { self != .focus }
}

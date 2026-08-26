import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case timer
    case sleepingDog

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .timer: "Timer"
        case .sleepingDog: "Sleeping Dog"
        }
    }
}

enum MenuBarRingDirection: String, CaseIterable, Identifiable, Sendable {
    case clockwise
    case counterclockwise

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .clockwise: "Clockwise"
        case .counterclockwise: "Counterclockwise"
        }
    }
}

enum MenuBarRingAppearance: String, Sendable {
    case standard
    case discreet
}

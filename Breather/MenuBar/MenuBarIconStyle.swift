import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case timer
    case sleepingCat

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .timer: "Timer"
        case .sleepingCat: "Sleeping Cat"
        }
    }
}

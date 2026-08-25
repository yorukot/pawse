enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case timer
    case sleepingCat

    var id: Self { self }

    var displayName: String {
        switch self {
        case .timer: "Timer"
        case .sleepingCat: "Sleeping Cat"
        }
    }
}

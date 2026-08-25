import Foundation

struct PawseBuildInfo: Equatable {
    static let unavailableValue = "—"

    let version: String
    let build: String

    init(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        version = Self.displayValue(
            infoDictionary["CFBundleShortVersionString"]
        )
        build = Self.displayValue(infoDictionary["CFBundleVersion"])
    }

    private static func displayValue(_ value: Any?) -> String {
        let stringValue: String?
        switch value {
        case let value as String:
            stringValue = value
        case let value as NSNumber:
            stringValue = value.stringValue
        default:
            stringValue = nil
        }

        guard let stringValue else { return unavailableValue }
        let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? unavailableValue : trimmedValue
    }
}

enum PawseLinks {
    static let author = URL(string: "https://yorukot.me")!
    static let donate = URL(string: "https://yorukot.me/donate")!
    static let github = URL(string: "https://github.com/yorukot/pawse")!
}

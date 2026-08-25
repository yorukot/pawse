import AppKit
import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case english = "en"
    case spanish = "es"
    case japanese = "ja"
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"

    var id: Self { self }

    var autonym: String {
        switch self {
        case .automatic: ""
        case .english: "English"
        case .spanish: "Español"
        case .japanese: "日本語"
        case .traditionalChinese: "繁體中文"
        case .simplifiedChinese: "简体中文"
        }
    }

    func locale(systemLocale: Locale = .autoupdatingCurrent) -> Locale {
        guard self != .automatic else { return systemLocale }

        let languageCode: Locale.LanguageCode
        let script: Locale.Script?
        switch self {
        case .automatic:
            return systemLocale
        case .english:
            languageCode = Locale.LanguageCode("en")
            script = nil
        case .spanish:
            languageCode = Locale.LanguageCode("es")
            script = nil
        case .japanese:
            languageCode = Locale.LanguageCode("ja")
            script = nil
        case .traditionalChinese:
            languageCode = Locale.LanguageCode("zh")
            script = Locale.Script("Hant")
        case .simplifiedChinese:
            languageCode = Locale.LanguageCode("zh")
            script = Locale.Script("Hans")
        }

        return Locale(
            languageCode: languageCode,
            script: script,
            languageRegion: systemLocale.region
        )
    }
}

@MainActor
@Observable
final class AppLanguageStore {
    static let preferenceKey = "appLanguage"

    let launchLanguage: AppLanguage
    private(set) var selectedLanguage: AppLanguage

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedLanguage = defaults.string(forKey: Self.preferenceKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .automatic
        launchLanguage = storedLanguage
        selectedLanguage = storedLanguage
    }

    var locale: Locale {
        launchLanguage.locale()
    }

    func save(_ language: AppLanguage) {
        selectedLanguage = language
        if language == .automatic {
            defaults.removeObject(forKey: Self.preferenceKey)
        } else {
            defaults.set(language.rawValue, forKey: Self.preferenceKey)
        }
    }
}

@MainActor
protocol AppRestarting: AnyObject {
    var isRestarting: Bool { get }
    var errorMessage: LocalizedStringResource? { get }
    func restart()
}

@MainActor
@Observable
final class AppRestartService: AppRestarting {
    private(set) var isRestarting = false
    private(set) var errorMessage: LocalizedStringResource?

    func restart() {
        guard !isRestarting else { return }
        isRestarting = true
        errorMessage = nil

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { [weak self] application, error in
            let succeeded = application != nil && error == nil
            let failureDescription = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRestarting = false
                if succeeded {
                    NSApp.terminate(nil)
                } else if let failureDescription {
                    self.errorMessage = "Breather could not restart: \(failureDescription). The new language will be used the next time you open Breather."
                } else {
                    self.errorMessage = "Breather could not restart. The new language will be used the next time you open Breather."
                }
            }
        }
    }
}

enum LocalizationText {
    static func string(_ resource: LocalizedStringResource, locale: Locale) -> String {
        var localizedResource = resource
        localizedResource.locale = locale
        return String(localized: localizedResource)
    }
}

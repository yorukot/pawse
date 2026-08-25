import Foundation
import XCTest
@testable import Breather

@MainActor
final class LocalizationTests: XCTestCase {
    private let supportedLocales = ["es", "ja", "zh-Hant", "zh-Hans"]

    func testLanguagePreferenceDefaultsPersistsAndRejectsUnknownValues() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var store = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(store.launchLanguage, .automatic)
        XCTAssertEqual(store.selectedLanguage, .automatic)

        store.save(.japanese)
        XCTAssertEqual(defaults.string(forKey: AppLanguageStore.preferenceKey), "ja")
        XCTAssertEqual(store.selectedLanguage, .japanese)
        XCTAssertEqual(store.launchLanguage, .automatic)

        store = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(store.launchLanguage, .japanese)
        XCTAssertEqual(store.selectedLanguage, .japanese)

        store.save(.automatic)
        XCTAssertNil(defaults.object(forKey: AppLanguageStore.preferenceKey))

        defaults.set("unsupported", forKey: AppLanguageStore.preferenceKey)
        store = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(store.launchLanguage, .automatic)
    }

    func testExplicitLanguagesProduceExpectedLanguageAndScript() {
        let systemLocale = Locale(identifier: "en_US")

        XCTAssertEqual(
            AppLanguage.english.locale(systemLocale: systemLocale).language.languageCode,
            Locale.LanguageCode("en")
        )
        XCTAssertEqual(
            AppLanguage.spanish.locale(systemLocale: systemLocale).language.languageCode,
            Locale.LanguageCode("es")
        )
        XCTAssertEqual(
            AppLanguage.japanese.locale(systemLocale: systemLocale).language.languageCode,
            Locale.LanguageCode("ja")
        )
        XCTAssertEqual(
            AppLanguage.traditionalChinese.locale(systemLocale: systemLocale).language.script,
            Locale.Script("Hant")
        )
        XCTAssertEqual(
            AppLanguage.simplifiedChinese.locale(systemLocale: systemLocale).language.script,
            Locale.Script("Hans")
        )
    }

    func testResettingSettingsPreservesLanguagePreference() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.traditionalChinese.rawValue, forKey: AppLanguageStore.preferenceKey)

        let settings = SettingsStore(defaults: defaults)
        settings.focusSeconds = 300
        settings.resetToDefaults()

        XCTAssertEqual(
            defaults.string(forKey: AppLanguageStore.preferenceKey),
            AppLanguage.traditionalChinese.rawValue
        )
    }

    func testKnownStringsResolveInEverySupportedLanguage() {
        let expectedFocus = [
            "es": "Concentración",
            "ja": "集中",
            "zh-Hant": "專注",
            "zh-Hans": "专注",
        ]

        for localeIdentifier in supportedLocales {
            let value = LocalizationText.string(
                "Focus",
                locale: Locale(identifier: localeIdentifier)
            )
            XCTAssertEqual(value, expectedFocus[localeIdentifier], localeIdentifier)
        }
    }

    func testDurationFormattingUsesTheSelectedLocale() {
        XCTAssertEqual(
            DurationFormatter.concise(90, locale: Locale(identifier: "en")),
            "1 min, 30 sec"
        )
        XCTAssertTrue(
            DurationFormatter.concise(90, locale: Locale(identifier: "ja")).contains("分")
        )
        XCTAssertTrue(
            DurationFormatter.concise(90, locale: Locale(identifier: "zh-Hant")).contains("分鐘")
        )
        XCTAssertTrue(
            DurationFormatter.concise(90, locale: Locale(identifier: "zh-Hans")).contains("分钟")
        )
    }

    func testStringCatalogHasCompleteTranslationsAndMatchingPlaceholders() throws {
        let catalogURL = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "Localizable.xcstrings",
                withExtension: "json"
            )
        )
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        XCTAssertFalse(strings.isEmpty)

        for (key, rawEntry) in strings {
            let entry = try XCTUnwrap(rawEntry as? [String: Any], key)
            let localizations = try XCTUnwrap(
                entry["localizations"] as? [String: Any],
                key
            )

            for localeIdentifier in supportedLocales {
                let localization = try XCTUnwrap(
                    localizations[localeIdentifier] as? [String: Any],
                    "\(key) [\(localeIdentifier)]"
                )
                let stringUnit = try XCTUnwrap(
                    localization["stringUnit"] as? [String: Any],
                    "\(key) [\(localeIdentifier)]"
                )
                let value = try XCTUnwrap(
                    stringUnit["value"] as? String,
                    "\(key) [\(localeIdentifier)]"
                )

                XCTAssertEqual(stringUnit["state"] as? String, "translated", key)
                XCTAssertFalse(value.isEmpty, "\(key) [\(localeIdentifier)]")
                XCTAssertEqual(
                    placeholders(in: value),
                    placeholders(in: key),
                    "\(key) [\(localeIdentifier)]"
                )
            }
        }
    }

    private func placeholders(in value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: "%(?:@|lld)")
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            Range(match.range, in: value).map { String(value[$0]) }
        }
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "PawseLocalizationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

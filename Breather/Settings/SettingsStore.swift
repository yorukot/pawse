import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    enum Key {
        static let focusSeconds = "focusSeconds"
        static let shortBreakSeconds = "shortBreakSeconds"
        static let longBreakSeconds = "longBreakSeconds"
        static let legacyFocusMinutes = "focusMinutes"
        static let legacyLongBreakMinutes = "longBreakMinutes"
        static let shortBreaksBeforeLongBreak = "shortBreaksBeforeLongBreak"
        static let automaticallyStartBreaks = "automaticallyStartBreaks"
        static let automaticallyStartNextFocus = "automaticallyStartNextFocus"
        static let waitForNaturalBreak = "waitForNaturalBreak"
        static let idleBeforeBreak = "idleBeforeBreak"
        static let breakEntryGracePeriod = "breakEntryGracePeriod"
        static let enableSounds = "enableSounds"
        static let sessionStartSound = "sessionStartSound"
        static let breakReadySound = "breakReadySound"
        static let breakCompleteSound = "breakCompleteSound"
        static let soundVolume = "soundVolume"
        static let showCountdownDuringBreak = "showCountdownDuringBreak"
        static let showSessionProgressInMenuBar = "showSessionProgressInMenuBar"
        static let menuBarIconStyle = "menuBarIconStyle"
        static let breakBackgroundMode = "breakBackgroundMode"
        static let customBreakImageBookmark = "customBreakImageBookmark"
        static let customBreakImageName = "customBreakImageName"
        static let focusCycleCount = "focusCycleCount"
    }

    private let defaults: UserDefaults
    private var isLoading = true

    static let focusDurationRange = 10...10_800
    static let shortBreakDurationRange = 10...3_600
    static let longBreakDurationRange = 10...7_200
    static let durationStep = 10

    var focusSeconds = 1_500 {
        didSet {
            let validated = normalizedDuration(focusSeconds, in: Self.focusDurationRange)
            guard validated == focusSeconds else { focusSeconds = validated; return }
            persist(Key.focusSeconds, focusSeconds)
        }
    }
    var shortBreakSeconds = 30 {
        didSet {
            let validated = normalizedDuration(shortBreakSeconds, in: Self.shortBreakDurationRange)
            guard validated == shortBreakSeconds else { shortBreakSeconds = validated; return }
            persist(Key.shortBreakSeconds, shortBreakSeconds)
        }
    }
    var longBreakSeconds = 600 {
        didSet {
            let validated = normalizedDuration(longBreakSeconds, in: Self.longBreakDurationRange)
            guard validated == longBreakSeconds else { longBreakSeconds = validated; return }
            persist(Key.longBreakSeconds, longBreakSeconds)
        }
    }
    var shortBreaksBeforeLongBreak = 2 {
        didSet {
            let validated = clamped(shortBreaksBeforeLongBreak, 1...12)
            guard validated == shortBreaksBeforeLongBreak else { shortBreaksBeforeLongBreak = validated; return }
            persist(Key.shortBreaksBeforeLongBreak, shortBreaksBeforeLongBreak)
        }
    }
    var automaticallyStartBreaks = true { didSet { persist(Key.automaticallyStartBreaks, automaticallyStartBreaks) } }
    var automaticallyStartNextFocus = true { didSet { persist(Key.automaticallyStartNextFocus, automaticallyStartNextFocus) } }
    var waitForNaturalBreak = true { didSet { persist(Key.waitForNaturalBreak, waitForNaturalBreak) } }
    var idleBeforeBreak: TimeInterval = 2 {
        didSet {
            let validated = allowedIdleDelay(idleBeforeBreak)
            guard validated == idleBeforeBreak else {
                idleBeforeBreak = validated
                return
            }
            persist(Key.idleBeforeBreak, idleBeforeBreak)
        }
    }
    var breakEntryGracePeriod: TimeInterval = 3 {
        didSet {
            let validated = min(10, max(1, breakEntryGracePeriod))
            guard validated == breakEntryGracePeriod else {
                breakEntryGracePeriod = validated
                return
            }
            persist(Key.breakEntryGracePeriod, breakEntryGracePeriod)
        }
    }
    var enableSounds = true { didSet { persist(Key.enableSounds, enableSounds) } }
    var sessionStartSound = "None" { didSet { persist(Key.sessionStartSound, sessionStartSound) } }
    var breakReadySound = "Glass" { didSet { persist(Key.breakReadySound, breakReadySound) } }
    var breakCompleteSound = "Glass" { didSet { persist(Key.breakCompleteSound, breakCompleteSound) } }
    var soundVolume = 0.7 {
        didSet {
            let validated = min(1, max(0, soundVolume))
            guard validated == soundVolume else {
                soundVolume = validated
                return
            }
            persist(Key.soundVolume, soundVolume)
        }
    }
    var showCountdownDuringBreak = true { didSet { persist(Key.showCountdownDuringBreak, showCountdownDuringBreak) } }
    var showSessionProgressInMenuBar = true { didSet { persist(Key.showSessionProgressInMenuBar, showSessionProgressInMenuBar) } }
    var menuBarIconStyle: MenuBarIconStyle = .sleepingCat {
        didSet { persist(Key.menuBarIconStyle, menuBarIconStyle.rawValue) }
    }
    var breakBackgroundMode: BreakBackgroundMode = .systemWallpaper {
        didSet { persist(Key.breakBackgroundMode, breakBackgroundMode.rawValue) }
    }
    private(set) var customBreakImageBookmark: Data? = nil {
        didSet { persistOptional(Key.customBreakImageBookmark, customBreakImageBookmark) }
    }
    private(set) var customBreakImageName: String? = nil {
        didSet { persistOptional(Key.customBreakImageName, customBreakImageName) }
    }
    var focusCycleCount = 0 {
        didSet {
            guard focusCycleCount >= 0 else {
                focusCycleCount = 0
                return
            }
            persist(Key.focusCycleCount, focusCycleCount)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateLegacyDurations(in: defaults)
        defaults.register(defaults: Self.defaultValues)
        load()
        isLoading = false
    }

    func duration(for mode: SessionMode) -> TimeInterval {
        switch mode {
        case .focus: TimeInterval(focusSeconds)
        case .shortBreak: TimeInterval(shortBreakSeconds)
        case .longBreak: TimeInterval(longBreakSeconds)
        }
    }

    func resetBreakCycle() {
        focusCycleCount = 0
    }

    func setCustomBreakImage(bookmark: Data, fileName: String) {
        customBreakImageBookmark = bookmark
        customBreakImageName = fileName
        breakBackgroundMode = .customImage
    }

    func clearCustomBreakImage() {
        customBreakImageBookmark = nil
        customBreakImageName = nil
        breakBackgroundMode = .systemWallpaper
    }

    func resetToDefaults() {
        focusSeconds = 1_500
        shortBreakSeconds = 30
        longBreakSeconds = 600
        shortBreaksBeforeLongBreak = 2
        automaticallyStartBreaks = true
        automaticallyStartNextFocus = true
        waitForNaturalBreak = true
        idleBeforeBreak = 2
        breakEntryGracePeriod = 3
        enableSounds = true
        sessionStartSound = "None"
        breakReadySound = "Glass"
        breakCompleteSound = "Glass"
        soundVolume = 0.7
        showCountdownDuringBreak = true
        showSessionProgressInMenuBar = true
        menuBarIconStyle = .sleepingCat
        clearCustomBreakImage()
    }

    private func load() {
        focusSeconds = defaults.integer(forKey: Key.focusSeconds)
        shortBreakSeconds = defaults.integer(forKey: Key.shortBreakSeconds)
        longBreakSeconds = defaults.integer(forKey: Key.longBreakSeconds)
        shortBreaksBeforeLongBreak = defaults.integer(forKey: Key.shortBreaksBeforeLongBreak)
        automaticallyStartBreaks = defaults.bool(forKey: Key.automaticallyStartBreaks)
        automaticallyStartNextFocus = defaults.bool(forKey: Key.automaticallyStartNextFocus)
        waitForNaturalBreak = defaults.bool(forKey: Key.waitForNaturalBreak)
        idleBeforeBreak = defaults.double(forKey: Key.idleBeforeBreak)
        breakEntryGracePeriod = defaults.double(forKey: Key.breakEntryGracePeriod)
        enableSounds = defaults.bool(forKey: Key.enableSounds)
        sessionStartSound = defaults.string(forKey: Key.sessionStartSound) ?? "None"
        breakReadySound = defaults.string(forKey: Key.breakReadySound) ?? "Glass"
        breakCompleteSound = defaults.string(forKey: Key.breakCompleteSound) ?? "Glass"
        soundVolume = defaults.double(forKey: Key.soundVolume)
        showCountdownDuringBreak = defaults.bool(forKey: Key.showCountdownDuringBreak)
        showSessionProgressInMenuBar = defaults.bool(forKey: Key.showSessionProgressInMenuBar)
        menuBarIconStyle = MenuBarIconStyle(
            rawValue: defaults.string(forKey: Key.menuBarIconStyle) ?? ""
        ) ?? .sleepingCat
        breakBackgroundMode = BreakBackgroundMode(
            rawValue: defaults.string(forKey: Key.breakBackgroundMode) ?? ""
        ) ?? .systemWallpaper
        customBreakImageBookmark = defaults.data(forKey: Key.customBreakImageBookmark)
        customBreakImageName = defaults.string(forKey: Key.customBreakImageName)
        focusCycleCount = defaults.integer(forKey: Key.focusCycleCount)
    }

    private func persist(_ key: String, _ value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }

    private func persistOptional(_ key: String, _ value: Any?) {
        guard !isLoading else { return }
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func clamped(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private func normalizedDuration(_ value: Int, in range: ClosedRange<Int>) -> Int {
        let clampedValue = clamped(value, range)
        let step = Self.durationStep
        return Int((Double(clampedValue) / Double(step)).rounded()) * step
    }

    private func allowedIdleDelay(_ value: TimeInterval) -> TimeInterval {
        let choices: [TimeInterval] = [2, 3, 5, 10, 15, 30]
        return choices.min(by: { abs($0 - value) < abs($1 - value) }) ?? 3
    }

    private static let defaultValues: [String: Any] = [
        Key.focusSeconds: 1_500,
        Key.shortBreakSeconds: 30,
        Key.longBreakSeconds: 600,
        Key.shortBreaksBeforeLongBreak: 2,
        Key.automaticallyStartBreaks: true,
        Key.automaticallyStartNextFocus: true,
        Key.waitForNaturalBreak: true,
        Key.idleBeforeBreak: 2.0,
        Key.breakEntryGracePeriod: 3.0,
        Key.enableSounds: true,
        Key.sessionStartSound: "None",
        Key.breakReadySound: "Glass",
        Key.breakCompleteSound: "Glass",
        Key.soundVolume: 0.7,
        Key.showCountdownDuringBreak: true,
        Key.showSessionProgressInMenuBar: true,
        Key.menuBarIconStyle: MenuBarIconStyle.sleepingCat.rawValue,
        Key.breakBackgroundMode: BreakBackgroundMode.systemWallpaper.rawValue,
        Key.focusCycleCount: 0
    ]

    private static func migrateLegacyDurations(in defaults: UserDefaults) {
        migrateLegacyDuration(
            in: defaults,
            legacyKey: Key.legacyFocusMinutes,
            secondsKey: Key.focusSeconds,
            range: focusDurationRange
        )
        migrateLegacyDuration(
            in: defaults,
            legacyKey: Key.legacyLongBreakMinutes,
            secondsKey: Key.longBreakSeconds,
            range: longBreakDurationRange
        )
    }

    private static func migrateLegacyDuration(
        in defaults: UserDefaults,
        legacyKey: String,
        secondsKey: String,
        range: ClosedRange<Int>
    ) {
        guard defaults.object(forKey: secondsKey) == nil,
              let legacyMinutes = defaults.object(forKey: legacyKey) as? NSNumber else {
            return
        }

        let seconds = legacyMinutes.intValue * 60
        defaults.set(min(range.upperBound, max(range.lowerBound, seconds)), forKey: secondsKey)
    }
}

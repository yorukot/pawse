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
        static let enableLongBreaks = "enableLongBreaks"
        static let shortBreaksBeforeLongBreak = "shortBreaksBeforeLongBreak"
        static let automaticallyStartBreaks = "automaticallyStartBreaks"
        static let automaticallyStartNextFocus = "automaticallyStartNextFocus"
        static let continueCycleAfterEmergencyExit = "continueCycleAfterEmergencyExit"
        static let waitForNaturalBreak = "waitForNaturalBreak"
        static let idleBeforeBreak = "idleBeforeBreak"
        static let breakEntryGracePeriod = "breakEntryGracePeriod"
        static let enableBreakSkipping = "enableBreakSkipping"
        static let minimumBreakSecondsBeforeSkipping = "minimumBreakSecondsBeforeSkipping"
        static let startBreaksInDiscreetMode = "startBreaksInDiscreetMode"
        static let showDiscreetBreakRing = "showDiscreetBreakRing"
        static let enableSounds = "enableSounds"
        static let sessionStartSound = "sessionStartSound"
        static let breakReadySound = "breakReadySound"
        static let breakCompleteSound = "breakCompleteSound"
        static let soundVolume = "soundVolume"
        static let showCountdownDuringBreak = "showCountdownDuringBreak"
        static let showSessionProgressInMenuBar = "showSessionProgressInMenuBar"
        static let menuBarIconStyle = "menuBarIconStyle"
        static let menuBarRingDirection = "menuBarRingDirection"
        static let breakBackgroundMode = "breakBackgroundMode"
        static let customBreakImageBookmark = "customBreakImageBookmark"
        static let customBreakImageName = "customBreakImageName"
        static let systemWallpaperFolderBookmark = "systemWallpaperFolderBookmark"
        static let systemWallpaperFolderName = "systemWallpaperFolderName"
        static let focusCycleCount = "focusCycleCount"
    }

    private let defaults: UserDefaults
    private var isLoading = true

    static let focusDurationRange = 10...10_800
    static let shortBreakDurationRange = 10...3_600
    static let longBreakDurationRange = 10...7_200
    static let breakSkipDelayRange = 10...7_200
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
    var enableLongBreaks = true {
        didSet {
            persist(Key.enableLongBreaks, enableLongBreaks)
            if !enableLongBreaks {
                focusCycleCount = 0
            }
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
    var continueCycleAfterEmergencyExit = true {
        didSet { persist(Key.continueCycleAfterEmergencyExit, continueCycleAfterEmergencyExit) }
    }
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
    var enableBreakSkipping = true {
        didSet { persist(Key.enableBreakSkipping, enableBreakSkipping) }
    }
    var minimumBreakSecondsBeforeSkipping = 30 {
        didSet {
            let validated = normalizedDuration(
                minimumBreakSecondsBeforeSkipping,
                in: Self.breakSkipDelayRange
            )
            guard validated == minimumBreakSecondsBeforeSkipping else {
                minimumBreakSecondsBeforeSkipping = validated
                return
            }
            persist(
                Key.minimumBreakSecondsBeforeSkipping,
                minimumBreakSecondsBeforeSkipping
            )
        }
    }
    var startBreaksInDiscreetMode = false {
        didSet { persist(Key.startBreaksInDiscreetMode, startBreaksInDiscreetMode) }
    }
    var showDiscreetBreakRing = true {
        didSet { persist(Key.showDiscreetBreakRing, showDiscreetBreakRing) }
    }
    var enableSounds = true { didSet { persist(Key.enableSounds, enableSounds) } }
    var sessionStartSound = "Submarine" { didSet { persist(Key.sessionStartSound, sessionStartSound) } }
    var breakReadySound = "None" { didSet { persist(Key.breakReadySound, breakReadySound) } }
    var breakCompleteSound = "Submarine" { didSet { persist(Key.breakCompleteSound, breakCompleteSound) } }
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
    var menuBarIconStyle: MenuBarIconStyle = .sleepingDog {
        didSet { persist(Key.menuBarIconStyle, menuBarIconStyle.rawValue) }
    }
    var menuBarRingDirection: MenuBarRingDirection = .clockwise {
        didSet { persist(Key.menuBarRingDirection, menuBarRingDirection.rawValue) }
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
    private(set) var systemWallpaperFolderBookmark: Data? = nil {
        didSet { persistOptional(Key.systemWallpaperFolderBookmark, systemWallpaperFolderBookmark) }
    }
    private(set) var systemWallpaperFolderName: String? = nil {
        didSet { persistOptional(Key.systemWallpaperFolderName, systemWallpaperFolderName) }
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
        if breakBackgroundMode == .customImage {
            breakBackgroundMode = .systemWallpaper
        }
    }

    func setSystemWallpaperFolder(bookmark: Data, folderName: String) {
        systemWallpaperFolderBookmark = bookmark
        systemWallpaperFolderName = folderName
    }

    func clearSystemWallpaperFolder() {
        systemWallpaperFolderBookmark = nil
        systemWallpaperFolderName = nil
    }

    func resetToDefaults() {
        focusSeconds = 1_500
        shortBreakSeconds = 30
        longBreakSeconds = 600
        enableLongBreaks = true
        shortBreaksBeforeLongBreak = 2
        automaticallyStartBreaks = true
        automaticallyStartNextFocus = true
        continueCycleAfterEmergencyExit = true
        waitForNaturalBreak = true
        idleBeforeBreak = 2
        breakEntryGracePeriod = 3
        enableBreakSkipping = true
        minimumBreakSecondsBeforeSkipping = 30
        startBreaksInDiscreetMode = false
        showDiscreetBreakRing = true
        enableSounds = true
        sessionStartSound = "Submarine"
        breakReadySound = "None"
        breakCompleteSound = "Submarine"
        soundVolume = 0.7
        showCountdownDuringBreak = true
        showSessionProgressInMenuBar = true
        menuBarIconStyle = .sleepingDog
        menuBarRingDirection = .clockwise
        clearCustomBreakImage()
        clearSystemWallpaperFolder()
        breakBackgroundMode = .systemWallpaper
    }

    private func load() {
        focusSeconds = defaults.integer(forKey: Key.focusSeconds)
        shortBreakSeconds = defaults.integer(forKey: Key.shortBreakSeconds)
        longBreakSeconds = defaults.integer(forKey: Key.longBreakSeconds)
        shortBreaksBeforeLongBreak = defaults.integer(forKey: Key.shortBreaksBeforeLongBreak)
        automaticallyStartBreaks = defaults.bool(forKey: Key.automaticallyStartBreaks)
        automaticallyStartNextFocus = defaults.bool(forKey: Key.automaticallyStartNextFocus)
        continueCycleAfterEmergencyExit = defaults.bool(forKey: Key.continueCycleAfterEmergencyExit)
        waitForNaturalBreak = defaults.bool(forKey: Key.waitForNaturalBreak)
        idleBeforeBreak = defaults.double(forKey: Key.idleBeforeBreak)
        breakEntryGracePeriod = defaults.double(forKey: Key.breakEntryGracePeriod)
        enableBreakSkipping = defaults.bool(forKey: Key.enableBreakSkipping)
        minimumBreakSecondsBeforeSkipping = defaults.integer(
            forKey: Key.minimumBreakSecondsBeforeSkipping
        )
        startBreaksInDiscreetMode = defaults.bool(forKey: Key.startBreaksInDiscreetMode)
        showDiscreetBreakRing = defaults.bool(forKey: Key.showDiscreetBreakRing)
        enableSounds = defaults.bool(forKey: Key.enableSounds)
        sessionStartSound = defaults.string(forKey: Key.sessionStartSound) ?? "Submarine"
        breakReadySound = defaults.string(forKey: Key.breakReadySound) ?? "None"
        breakCompleteSound = defaults.string(forKey: Key.breakCompleteSound) ?? "Submarine"
        soundVolume = defaults.double(forKey: Key.soundVolume)
        showCountdownDuringBreak = defaults.bool(forKey: Key.showCountdownDuringBreak)
        showSessionProgressInMenuBar = defaults.bool(forKey: Key.showSessionProgressInMenuBar)
        let storedMenuBarIconStyle = defaults.string(forKey: Key.menuBarIconStyle) ?? ""
        if storedMenuBarIconStyle == "sleepingCat" {
            menuBarIconStyle = .sleepingDog
            defaults.set(MenuBarIconStyle.sleepingDog.rawValue, forKey: Key.menuBarIconStyle)
        } else {
            menuBarIconStyle = MenuBarIconStyle(
                rawValue: storedMenuBarIconStyle
            ) ?? .sleepingDog
        }
        menuBarRingDirection = MenuBarRingDirection(
            rawValue: defaults.string(forKey: Key.menuBarRingDirection) ?? ""
        ) ?? .clockwise
        breakBackgroundMode = BreakBackgroundMode(
            rawValue: defaults.string(forKey: Key.breakBackgroundMode) ?? ""
        ) ?? .systemWallpaper
        customBreakImageBookmark = defaults.data(forKey: Key.customBreakImageBookmark)
        customBreakImageName = defaults.string(forKey: Key.customBreakImageName)
        systemWallpaperFolderBookmark = defaults.data(forKey: Key.systemWallpaperFolderBookmark)
        systemWallpaperFolderName = defaults.string(forKey: Key.systemWallpaperFolderName)
        focusCycleCount = defaults.integer(forKey: Key.focusCycleCount)
        enableLongBreaks = defaults.bool(forKey: Key.enableLongBreaks)
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
        Key.enableLongBreaks: true,
        Key.shortBreaksBeforeLongBreak: 2,
        Key.automaticallyStartBreaks: true,
        Key.automaticallyStartNextFocus: true,
        Key.continueCycleAfterEmergencyExit: true,
        Key.waitForNaturalBreak: true,
        Key.idleBeforeBreak: 2.0,
        Key.breakEntryGracePeriod: 3.0,
        Key.enableBreakSkipping: true,
        Key.minimumBreakSecondsBeforeSkipping: 30,
        Key.startBreaksInDiscreetMode: false,
        Key.showDiscreetBreakRing: true,
        Key.enableSounds: true,
        Key.sessionStartSound: "Submarine",
        Key.breakReadySound: "None",
        Key.breakCompleteSound: "Submarine",
        Key.soundVolume: 0.7,
        Key.showCountdownDuringBreak: true,
        Key.showSessionProgressInMenuBar: true,
        Key.menuBarIconStyle: MenuBarIconStyle.sleepingDog.rawValue,
        Key.menuBarRingDirection: MenuBarRingDirection.clockwise.rawValue,
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

import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    enum Key {
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let longBreakEvery = "longBreakEvery"
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
        static let focusCycleCount = "focusCycleCount"
    }

    private let defaults: UserDefaults
    private var isLoading = true

    var focusMinutes = 25 {
        didSet {
            let validated = clamped(focusMinutes, 1...180)
            guard validated == focusMinutes else { focusMinutes = validated; return }
            persist(Key.focusMinutes, focusMinutes)
        }
    }
    var shortBreakMinutes = 5 {
        didSet {
            let validated = clamped(shortBreakMinutes, 1...60)
            guard validated == shortBreakMinutes else { shortBreakMinutes = validated; return }
            persist(Key.shortBreakMinutes, shortBreakMinutes)
        }
    }
    var longBreakMinutes = 15 {
        didSet {
            let validated = clamped(longBreakMinutes, 1...120)
            guard validated == longBreakMinutes else { longBreakMinutes = validated; return }
            persist(Key.longBreakMinutes, longBreakMinutes)
        }
    }
    var longBreakEvery = 4 {
        didSet {
            let validated = clamped(longBreakEvery, 2...12)
            guard validated == longBreakEvery else { longBreakEvery = validated; return }
            persist(Key.longBreakEvery, longBreakEvery)
        }
    }
    var automaticallyStartBreaks = true { didSet { persist(Key.automaticallyStartBreaks, automaticallyStartBreaks) } }
    var automaticallyStartNextFocus = false { didSet { persist(Key.automaticallyStartNextFocus, automaticallyStartNextFocus) } }
    var waitForNaturalBreak = true { didSet { persist(Key.waitForNaturalBreak, waitForNaturalBreak) } }
    var idleBeforeBreak: TimeInterval = 5 {
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
        defaults.register(defaults: Self.defaultValues)
        load()
        isLoading = false
    }

    func duration(for mode: SessionMode) -> TimeInterval {
        switch mode {
        case .focus: TimeInterval(focusMinutes * 60)
        case .shortBreak: TimeInterval(shortBreakMinutes * 60)
        case .longBreak: TimeInterval(longBreakMinutes * 60)
        }
    }

    func resetFocusCycle() {
        focusCycleCount = 0
    }

    func resetToDefaults() {
        focusMinutes = 25
        shortBreakMinutes = 5
        longBreakMinutes = 15
        longBreakEvery = 4
        automaticallyStartBreaks = true
        automaticallyStartNextFocus = false
        waitForNaturalBreak = true
        idleBeforeBreak = 5
        breakEntryGracePeriod = 3
        enableSounds = true
        sessionStartSound = "None"
        breakReadySound = "Glass"
        breakCompleteSound = "Glass"
        soundVolume = 0.7
        showCountdownDuringBreak = true
        showSessionProgressInMenuBar = true
    }

    private func load() {
        focusMinutes = defaults.integer(forKey: Key.focusMinutes)
        shortBreakMinutes = defaults.integer(forKey: Key.shortBreakMinutes)
        longBreakMinutes = defaults.integer(forKey: Key.longBreakMinutes)
        longBreakEvery = defaults.integer(forKey: Key.longBreakEvery)
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
        focusCycleCount = defaults.integer(forKey: Key.focusCycleCount)
    }

    private func persist(_ key: String, _ value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }

    private func clamped(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private func allowedIdleDelay(_ value: TimeInterval) -> TimeInterval {
        let choices: [TimeInterval] = [2, 3, 5, 10, 15, 30]
        return choices.min(by: { abs($0 - value) < abs($1 - value) }) ?? 5
    }

    private static let defaultValues: [String: Any] = [
        Key.focusMinutes: 25,
        Key.shortBreakMinutes: 5,
        Key.longBreakMinutes: 15,
        Key.longBreakEvery: 4,
        Key.automaticallyStartBreaks: true,
        Key.automaticallyStartNextFocus: false,
        Key.waitForNaturalBreak: true,
        Key.idleBeforeBreak: 5.0,
        Key.breakEntryGracePeriod: 3.0,
        Key.enableSounds: true,
        Key.sessionStartSound: "None",
        Key.breakReadySound: "Glass",
        Key.breakCompleteSound: "Glass",
        Key.soundVolume: 0.7,
        Key.showCountdownDuringBreak: true,
        Key.showSessionProgressInMenuBar: true,
        Key.focusCycleCount: 0
    ]
}

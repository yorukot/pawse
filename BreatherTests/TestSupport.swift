import Foundation
import XCTest
@testable import Breather

final class FakeSessionClock: SessionClock {
    var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    func advance(_ interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

@MainActor
final class FakeRepeatingScheduler: RepeatingScheduling {
    private(set) var isScheduled = false
    private(set) var interval: TimeInterval?
    private(set) var scheduleCount = 0
    private(set) var cancelCount = 0
    private var action: (@MainActor () -> Void)?

    func schedule(every interval: TimeInterval, action: @escaping @MainActor () -> Void) {
        isScheduled = true
        self.interval = interval
        self.action = action
        scheduleCount += 1
    }

    func cancel() {
        if isScheduled { cancelCount += 1 }
        isScheduled = false
        interval = nil
        action = nil
    }

    func fire() {
        action?()
    }
}

final class FakeUserActivityMonitor: UserActivityMonitoring {
    var current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 0)
    private(set) var sampleCount = 0

    func sample() -> UserActivitySample {
        sampleCount += 1
        return current
    }
}

@MainActor
final class FakeSoundPlayer: SoundPlaying {
    private(set) var events: [SoundEvent] = []
    private(set) var stopCount = 0

    func play(_ event: SoundEvent) {
        events.append(event)
    }

    func stopAll() {
        stopCount += 1
    }
}

@MainActor
final class FakeSessionRecorder: SessionRecording {
    private(set) var records: [SessionRecordSnapshot] = []

    func record(_ session: SessionRecordSnapshot) {
        guard !records.contains(where: { $0.id == session.id }) else { return }
        records.append(session)
    }
}

@MainActor
final class FakeBreakEnvironment: BreakEnvironmentManaging {
    private(set) var reminderModes: [SessionMode] = []
    private(set) var pendingReminders: [PendingBreak] = []
    private(set) var hideReminderCount = 0
    private(set) var overlayModes: [SessionMode] = []
    private(set) var commitPresentationCount = 0
    private(set) var cleanupCount = 0
    private(set) var cleanupAnimationValues: [Bool] = []
    var shouldFailOverlay = false

    func showReminder(for pendingBreak: PendingBreak) {
        pendingReminders.append(pendingBreak)
        reminderModes.append(pendingBreak.mode)
    }

    func hideReminder() {
        hideReminderCount += 1
    }

    func showEntryOverlays(for mode: SessionMode) throws {
        if shouldFailOverlay { throw BreakEnvironmentError.overlayCreationFailed }
        overlayModes.append(mode)
    }

    func commitPresentation() {
        commitPresentationCount += 1
    }

    func cleanup(animated: Bool) {
        cleanupCount += 1
        cleanupAnimationValues.append(animated)
    }
}

@MainActor
final class ControllerHarness {
    let defaults: UserDefaults
    let settings: SettingsStore
    let clock: FakeSessionClock
    let scheduler: FakeRepeatingScheduler
    let activity: FakeUserActivityMonitor
    let sound: FakeSoundPlayer
    let recorder: FakeSessionRecorder
    let environment: FakeBreakEnvironment
    let controller: SessionController

    init(configure: (SettingsStore) -> Void = { _ in }) {
        let suiteName = "BreatherTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        let settings = SettingsStore(defaults: defaults)
        settings.focusMinutes = 1
        settings.shortBreakSeconds = 60
        settings.longBreakMinutes = 1
        settings.idleBeforeBreak = 5
        settings.breakEntryGracePeriod = 3
        settings.automaticallyStartNextFocus = false
        configure(settings)

        let clock = FakeSessionClock()
        let scheduler = FakeRepeatingScheduler()
        let activity = FakeUserActivityMonitor()
        let sound = FakeSoundPlayer()
        let recorder = FakeSessionRecorder()
        let environment = FakeBreakEnvironment()

        self.defaults = defaults
        self.settings = settings
        self.clock = clock
        self.scheduler = scheduler
        self.activity = activity
        self.sound = sound
        self.recorder = recorder
        self.environment = environment
        controller = SessionController(
            settings: settings,
            clock: clock,
            scheduler: scheduler,
            activityMonitor: activity,
            soundPlayer: sound,
            analyticsRecorder: recorder,
            breakEnvironment: environment
        )
    }

    func advance(_ interval: TimeInterval, tick: Bool = true) {
        clock.advance(interval)
        if tick { controller.handleTick() }
    }

    func startFocus() {
        controller.selectMode(.focus)
        controller.startSelectedMode()
    }

    func completeFocus() {
        startFocus()
        advance(60)
    }

    func commitPendingBreak() {
        controller.startPendingBreakNow()
        advance(settings.breakEntryGracePeriod)
    }
}

func makeSnapshot(
    id: UUID = UUID(),
    mode: SessionMode = .focus,
    origin: SessionOrigin = .manual,
    outcome: SessionOutcome = .completed,
    startedAt: Date,
    endedAt: Date? = nil,
    plannedDuration: TimeInterval = 1_500,
    activeDuration: TimeInterval = 1_500,
    scheduledAt: Date? = nil,
    cyclePosition: Int? = nil
) -> SessionRecordSnapshot {
    SessionRecordSnapshot(
        id: id,
        mode: mode,
        origin: origin,
        outcome: outcome,
        startedAt: startedAt,
        endedAt: endedAt ?? startedAt.addingTimeInterval(activeDuration),
        plannedDuration: plannedDuration,
        activeDuration: activeDuration,
        scheduledAt: scheduledAt,
        cyclePosition: cyclePosition
    )
}

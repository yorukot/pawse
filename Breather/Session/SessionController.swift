import Foundation
import Observation

@MainActor
@Observable
final class SessionController {
    static let breakReminderLeadTime: TimeInterval = 10

    private(set) var state: SessionState = .idle(selectedMode: .focus)
    private(set) var nowSnapshot: Date
    private(set) var modeSwitchTarget: SessionMode?
    private(set) var isEmergencyExitConfirmationPresented = false
    private(set) var lastError: LocalizedStringResource?

    let settings: SettingsStore
    private let clock: SessionClock
    private let scheduler: RepeatingScheduling
    private let activityMonitor: UserActivityMonitoring
    private let soundPlayer: SoundPlaying
    private let analyticsRecorder: SessionRecording
    private let breakEnvironment: BreakEnvironmentManaging

    private var entryActivityBaseline: UInt64?
    private var activeReminderPresentation: BreakReminderPresentation?
    private var finalizedSessionIDs: Set<UUID> = []

    init(
        settings: SettingsStore,
        clock: SessionClock,
        scheduler: RepeatingScheduling,
        activityMonitor: UserActivityMonitoring,
        soundPlayer: SoundPlaying,
        analyticsRecorder: SessionRecording,
        breakEnvironment: BreakEnvironmentManaging
    ) {
        self.settings = settings
        self.clock = clock
        self.scheduler = scheduler
        self.activityMonitor = activityMonitor
        self.soundPlayer = soundPlayer
        self.analyticsRecorder = analyticsRecorder
        self.breakEnvironment = breakEnvironment
        nowSnapshot = clock.now
    }

    var remainingTime: TimeInterval {
        switch state {
        case .idle(let mode): settings.duration(for: mode)
        case .running(let session): session.remaining(at: nowSnapshot)
        case .paused(let session): max(0, session.remainingDuration)
        case .breakPending(let pending): pending.plannedDuration
        case .breakEntering(let entry): max(0, entry.plannedDuration - nowSnapshot.timeIntervalSince(entry.beganEnteringAt))
        }
    }

    var progress: Double {
        let planned: TimeInterval
        switch state {
        case .running(let session): planned = session.plannedDuration
        case .paused(let session): planned = session.plannedDuration
        case .breakEntering(let entry): planned = entry.plannedDuration
        default: return 0
        }
        guard planned > 0 else { return 0 }
        return min(1, max(0, 1 - remainingTime / planned))
    }

    var countdownFractionRemaining: Double? {
        let plannedDuration: TimeInterval
        switch state {
        case .running(let session): plannedDuration = session.plannedDuration
        case .paused(let session): plannedDuration = session.plannedDuration
        case .breakEntering(let entry): plannedDuration = entry.plannedDuration
        default: return nil
        }
        guard plannedDuration > 0 else { return 0 }
        return min(1, max(0, remainingTime / plannedDuration))
    }

    var currentMode: SessionMode { state.selectedOrCurrentMode }

    var upcomingBreakSummary: UpcomingBreakSummary {
        projectedBreakSummary()
    }

    var isFocusRunningOrPaused: Bool {
        switch state {
        case .running(let session): session.mode == .focus
        case .paused: true
        default: false
        }
    }

    func selectMode(_ mode: SessionMode) {
        guard case .idle = state else { return }
        state = .idle(selectedMode: mode)
        refreshNow()
    }

    func startSelectedMode() {
        guard case .idle(let mode) = state else { return }
        startSession(mode: mode, origin: .manual, scheduledAt: nil, cyclePosition: nil)
    }

    func startFocusAtLaunch() {
        guard case .idle = state else { return }
        state = .idle(selectedMode: .focus)
        startSession(mode: .focus, origin: .automatic, scheduledAt: nil, cyclePosition: nil)
    }

    func pauseFocus() {
        guard case .running(let session) = state, session.mode == .focus else { return }
        let now = clock.now
        let paused = PausedSession(
            id: session.id,
            mode: session.mode,
            origin: session.origin,
            startedAt: session.startedAt,
            scheduledAt: session.scheduledAt,
            plannedDuration: session.plannedDuration,
            remainingDuration: session.remaining(at: now),
            accumulatedActiveDuration: session.activeDuration(at: now),
            cyclePosition: session.cyclePosition
        )
        state = .paused(paused)
        nowSnapshot = now
        scheduler.cancel()
        hideBreakReminder()
    }

    func resumeFocus() {
        guard case .paused(let paused) = state else { return }
        let now = clock.now
        let running = RunningSession(
            id: paused.id,
            mode: paused.mode,
            origin: paused.origin,
            startedAt: paused.startedAt,
            scheduledAt: paused.scheduledAt,
            plannedDuration: paused.plannedDuration,
            deadline: now.addingTimeInterval(paused.remainingDuration),
            activeStartedAt: now,
            accumulatedActiveDuration: paused.accumulatedActiveDuration,
            cyclePosition: paused.cyclePosition
        )
        state = .running(running)
        nowSnapshot = now
        schedule(every: 1)
        updateUpcomingReminder(for: running, at: now)
    }

    func stopCurrentSession() {
        let now = clock.now
        switch state {
        case .running(let session) where session.mode == .focus:
            finalize(session, outcome: .stopped, endedAt: now, activeDuration: session.activeDuration(at: now))
            scheduler.cancel()
            hideBreakReminder()
            state = .idle(selectedMode: .focus)
            nowSnapshot = now
        case .paused(let session):
            finalize(session, outcome: .stopped, endedAt: now, activeDuration: session.accumulatedActiveDuration)
            scheduler.cancel()
            state = .idle(selectedMode: .focus)
            nowSnapshot = now
        default:
            break
        }
    }

    func requestModeSwitch(to mode: SessionMode) {
        guard isFocusRunningOrPaused, mode != .focus else { return }
        modeSwitchTarget = mode
    }

    func cancelModeSwitch() {
        modeSwitchTarget = nil
    }

    func confirmModeSwitch() {
        guard let target = modeSwitchTarget else { return }
        let now = clock.now
        switch state {
        case .running(let session) where session.mode == .focus:
            finalize(session, outcome: .switchedMode, endedAt: now, activeDuration: session.activeDuration(at: now))
        case .paused(let session):
            finalize(session, outcome: .switchedMode, endedAt: now, activeDuration: session.accumulatedActiveDuration)
        default:
            modeSwitchTarget = nil
            return
        }
        scheduler.cancel()
        hideBreakReminder()
        modeSwitchTarget = nil
        state = .idle(selectedMode: target)
        startSession(mode: target, origin: .manual, scheduledAt: nil, cyclePosition: nil)
    }

    func startPendingBreakNow() {
        guard case .breakPending(let pending) = state else { return }
        beginBreakEntry(pending)
    }

    func startBreakFromReminder() {
        switch state {
        case .running(let session) where session.mode == .focus:
            let now = clock.now
            guard settings.automaticallyStartBreaks,
                  session.remaining(at: now) <= Self.breakReminderLeadTime else { return }
            finalize(
                session,
                outcome: .completed,
                endedAt: now,
                activeDuration: session.activeDuration(at: now)
            )
            completeFocus(at: now, startBreakImmediately: true)
        case .breakPending(let pending):
            beginBreakEntry(pending)
        default:
            break
        }
    }

    func cancelPendingBreak() {
        guard case .breakPending = state else { return }
        cleanupBreakEnvironment(animated: false)
        state = .idle(selectedMode: .focus)
        refreshNow()
    }

    func requestEmergencyExit() {
        guard case .running(let session) = state, session.mode.isBreak else { return }
        isEmergencyExitConfirmationPresented = true
    }

    func cancelEmergencyExit() {
        isEmergencyExitConfirmationPresented = false
    }

    func confirmEmergencyExit() {
        guard isEmergencyExitConfirmationPresented,
              case .running(let session) = state,
              session.mode.isBreak else { return }
        let now = clock.now
        isEmergencyExitConfirmationPresented = false
        finalize(session, outcome: .emergencyExit, endedAt: now, activeDuration: session.activeDuration(at: now))
        cleanupBreakEnvironment(animated: false)
        state = .idle(selectedMode: .focus)
        nowSnapshot = now
    }

    func handleTick() {
        let now = clock.now
        nowSnapshot = now
        switch state {
        case .running(let session):
            if now >= session.deadline {
                completeRunningSession(session, at: now)
            } else if session.mode == .focus {
                updateUpcomingReminder(for: session, at: now)
            }
        case .breakPending(let pending):
            let sample = activityMonitor.sample()
            if sample.secondsSinceLastInput >= settings.idleBeforeBreak {
                beginBreakEntry(pending)
            }
        case .breakEntering(let entry):
            let sample = activityMonitor.sample()
            if let baseline = entryActivityBaseline, sample.activityToken != baseline {
                cancelBreakEntry(entry)
            } else if now.timeIntervalSince(entry.beganEnteringAt) >= settings.breakEntryGracePeriod {
                commitBreakEntry(entry)
            }
        default:
            break
        }
    }

    func cleanupBreakEnvironment(animated: Bool = true) {
        scheduler.cancel()
        breakEnvironment.cleanup(animated: animated)
        soundPlayer.stopAll()
        entryActivityBaseline = nil
        activeReminderPresentation = nil
        isEmergencyExitConfirmationPresented = false
    }

    func handleBreakEnvironmentFailure() {
        switch state {
        case .running(let session) where session.mode.isBreak:
            let now = clock.now
            finalize(
                session,
                outcome: .stopped,
                endedAt: now,
                activeDuration: session.activeDuration(at: now)
            )
            cleanupBreakEnvironment(animated: false)
            lastError = "Breather could not keep every display covered. The break was canceled for safety."
            state = .idle(selectedMode: .focus)
            nowSnapshot = now
        case .breakEntering:
            cleanupBreakEnvironment(animated: false)
            lastError = "Breather could not keep every display covered. The break was canceled for safety."
            state = .idle(selectedMode: .focus)
            refreshNow()
        default:
            break
        }
    }

    func prepareForTermination() {
        let now = clock.now
        switch state {
        case .running(let session):
            let outcome: SessionOutcome = session.mode == .focus ? .stopped : .emergencyExit
            finalize(session, outcome: outcome, endedAt: now, activeDuration: session.activeDuration(at: now))
        case .paused(let session):
            finalize(session, outcome: .stopped, endedAt: now, activeDuration: session.accumulatedActiveDuration)
        default:
            break
        }
        cleanupBreakEnvironment(animated: false)
        state = .idle(selectedMode: .focus)
        nowSnapshot = now
    }

    private func startSession(
        mode: SessionMode,
        origin: SessionOrigin,
        scheduledAt: Date?,
        cyclePosition: Int?
    ) {
        guard case .idle = state else { return }
        let now = clock.now
        let duration = settings.duration(for: mode)
        let session = RunningSession(
            id: UUID(),
            mode: mode,
            origin: origin,
            startedAt: now,
            scheduledAt: scheduledAt,
            plannedDuration: duration,
            deadline: now.addingTimeInterval(duration),
            activeStartedAt: now,
            accumulatedActiveDuration: 0,
            cyclePosition: cyclePosition
        )
        if mode.isBreak {
            activeReminderPresentation = nil
            do {
                try breakEnvironment.showEntryOverlays(for: mode)
                breakEnvironment.commitPresentation()
            } catch {
                handleOverlayFailure()
                return
            }
        }
        state = .running(session)
        nowSnapshot = now
        playSound(.sessionStarted(mode))
        schedule(every: 1)
        if mode == .focus {
            updateUpcomingReminder(for: session, at: now)
        }
    }

    private func completeRunningSession(_ session: RunningSession, at now: Date) {
        guard !finalizedSessionIDs.contains(session.id) else { return }
        finalize(session, outcome: .completed, endedAt: now, activeDuration: session.plannedDuration)
        if session.mode == .focus {
            completeFocus(at: now, startBreakImmediately: false)
        } else {
            completeBreak(session, at: now)
        }
    }

    private func completeFocus(at now: Date, startBreakImmediately: Bool) {
        scheduler.cancel()
        settings.focusCycleCount += 1
        let breakMode = scheduledBreakMode(afterCompletedFocusCount: settings.focusCycleCount)
        let duration = settings.duration(for: breakMode)

        guard settings.automaticallyStartBreaks else {
            hideBreakReminder()
            playSound(.focusCompleted)
            state = .idle(selectedMode: breakMode)
            nowSnapshot = now
            return
        }

        if settings.waitForNaturalBreak {
            let pending = PendingBreak(
                id: UUID(),
                mode: breakMode,
                scheduledAt: now,
                origin: .automatic,
                cyclePosition: settings.focusCycleCount,
                plannedDuration: duration
            )
            state = .breakPending(pending)
            nowSnapshot = now
            playSound(.breakReady(breakMode))
            if startBreakImmediately {
                beginBreakEntry(pending)
            } else {
                showBreakReadyReminder(for: pending)
                schedule(every: 0.25)
            }
        } else {
            state = .idle(selectedMode: breakMode)
            startSession(
                mode: breakMode,
                origin: .automatic,
                scheduledAt: now,
                cyclePosition: settings.focusCycleCount
            )
        }
    }

    private func completeBreak(_ session: RunningSession, at now: Date) {
        if session.origin == .automatic && session.mode == .longBreak {
            settings.focusCycleCount = 0
        }
        cleanupBreakEnvironment()
        playSound(.breakCompleted(session.mode))
        state = .idle(selectedMode: .focus)
        nowSnapshot = now
        if settings.automaticallyStartNextFocus {
            startSession(mode: .focus, origin: .automatic, scheduledAt: nil, cyclePosition: nil)
        }
    }

    private func beginBreakEntry(_ pending: PendingBreak) {
        guard case .breakPending(let current) = state, current.id == pending.id else { return }
        let now = clock.now
        breakEnvironment.hideReminder()
        activeReminderPresentation = nil
        do {
            try breakEnvironment.showEntryOverlays(for: pending.mode)
        } catch {
            handleOverlayFailure()
            return
        }
        let entry = BreakEntry(
            id: pending.id,
            mode: pending.mode,
            scheduledAt: pending.scheduledAt,
            beganEnteringAt: now,
            origin: pending.origin,
            cyclePosition: pending.cyclePosition,
            plannedDuration: pending.plannedDuration
        )
        entryActivityBaseline = activityMonitor.sample().activityToken
        state = .breakEntering(entry)
        nowSnapshot = now
        schedule(every: 0.25)
    }

    private func cancelBreakEntry(_ entry: BreakEntry) {
        guard case .breakEntering(let current) = state, current.id == entry.id else { return }
        cleanupBreakEnvironment()
        let pending = PendingBreak(
            id: entry.id,
            mode: entry.mode,
            scheduledAt: entry.scheduledAt,
            origin: entry.origin,
            cyclePosition: entry.cyclePosition,
            plannedDuration: entry.plannedDuration
        )
        state = .breakPending(pending)
        showBreakReadyReminder(for: pending)
        refreshNow()
        schedule(every: 0.25)
    }

    private func commitBreakEntry(_ entry: BreakEntry) {
        guard case .breakEntering(let current) = state, current.id == entry.id else { return }
        let now = clock.now
        let elapsed = max(0, now.timeIntervalSince(entry.beganEnteringAt))
        let remaining = max(0, entry.plannedDuration - elapsed)
        let running = RunningSession(
            id: entry.id,
            mode: entry.mode,
            origin: entry.origin,
            startedAt: entry.beganEnteringAt,
            scheduledAt: entry.scheduledAt,
            plannedDuration: entry.plannedDuration,
            deadline: now.addingTimeInterval(remaining),
            activeStartedAt: entry.beganEnteringAt,
            accumulatedActiveDuration: 0,
            cyclePosition: entry.cyclePosition
        )
        entryActivityBaseline = nil
        state = .running(running)
        nowSnapshot = now
        breakEnvironment.commitPresentation()
        playSound(.breakStarted(entry.mode))
        schedule(every: 1)
    }

    private func handleOverlayFailure() {
        cleanupBreakEnvironment(animated: false)
        lastError = "Breather could not cover every display. The break was canceled for safety."
        state = .idle(selectedMode: .focus)
        refreshNow()
    }

    private func updateUpcomingReminder(for session: RunningSession, at now: Date) {
        guard session.mode == .focus else { return }
        guard settings.automaticallyStartBreaks else {
            hideBreakReminder()
            return
        }

        let remaining = session.remaining(at: now)
        guard remaining <= Self.breakReminderLeadTime else {
            hideBreakReminder()
            return
        }

        let mode = scheduledBreakMode(
            afterCompletedFocusCount: settings.focusCycleCount + 1
        )
        showBreakReminder(
            BreakReminderPresentation(
                mode: mode,
                phase: .upcoming(
                    deadline: session.deadline,
                    leadTime: Self.breakReminderLeadTime
                )
            )
        )
    }

    private func showBreakReadyReminder(for pending: PendingBreak) {
        showBreakReminder(
            BreakReminderPresentation(
                mode: pending.mode,
                phase: .ready(scheduledAt: pending.scheduledAt)
            )
        )
    }

    private func showBreakReminder(_ presentation: BreakReminderPresentation) {
        guard activeReminderPresentation != presentation else { return }
        activeReminderPresentation = presentation
        breakEnvironment.showReminder(presentation)
    }

    private func hideBreakReminder() {
        guard activeReminderPresentation != nil else { return }
        breakEnvironment.hideReminder()
        activeReminderPresentation = nil
    }

    private func scheduledBreakMode(afterCompletedFocusCount count: Int) -> SessionMode {
        count > settings.shortBreaksBeforeLongBreak ? .longBreak : .shortBreak
    }

    private func projectedBreakSummary() -> UpcomingBreakSummary {
        var shortBreak: UpcomingBreakTiming?
        var longBreak: UpcomingBreakTiming?
        var elapsed: TimeInterval
        var focusCycleCount = settings.focusCycleCount

        switch state {
        case .idle:
            elapsed = settings.duration(for: .focus)
        case .running(let session) where session.mode == .focus:
            elapsed = session.remaining(at: nowSnapshot)
        case .paused(let session):
            elapsed = max(0, session.remainingDuration)
        case .running(let session):
            if session.mode == .shortBreak {
                shortBreak = .inProgress
            } else {
                longBreak = .inProgress
            }
            elapsed = session.remaining(at: nowSnapshot)
            if session.origin == .automatic && session.mode == .longBreak {
                focusCycleCount = 0
            }
            elapsed += settings.duration(for: .focus)
        case .breakPending(let pending):
            if pending.mode == .shortBreak {
                shortBreak = .readyNow
            } else {
                longBreak = .readyNow
            }
            elapsed = pending.plannedDuration
            if pending.origin == .automatic && pending.mode == .longBreak {
                focusCycleCount = 0
            }
            elapsed += settings.duration(for: .focus)
        case .breakEntering(let entry):
            if entry.mode == .shortBreak {
                shortBreak = .inProgress
            } else {
                longBreak = .inProgress
            }
            elapsed = max(
                0,
                entry.plannedDuration - nowSnapshot.timeIntervalSince(entry.beganEnteringAt)
            )
            if entry.origin == .automatic && entry.mode == .longBreak {
                focusCycleCount = 0
            }
            elapsed += settings.duration(for: .focus)
        }

        for _ in 0..<64 where shortBreak == nil || longBreak == nil {
            focusCycleCount += 1
            let mode = scheduledBreakMode(afterCompletedFocusCount: focusCycleCount)
            let timing = UpcomingBreakTiming.estimated(max(0, elapsed))

            if mode == .shortBreak, shortBreak == nil {
                shortBreak = timing
            } else if mode == .longBreak, longBreak == nil {
                longBreak = timing
            }

            elapsed += settings.duration(for: mode)
            if mode == .longBreak {
                focusCycleCount = 0
            }
            elapsed += settings.duration(for: .focus)
        }

        return UpcomingBreakSummary(
            shortBreak: shortBreak ?? .estimated(max(0, elapsed)),
            longBreak: longBreak ?? .estimated(max(0, elapsed))
        )
    }

    private func finalize(
        _ session: RunningSession,
        outcome: SessionOutcome,
        endedAt: Date,
        activeDuration: TimeInterval
    ) {
        finalize(
            id: session.id,
            mode: session.mode,
            origin: session.origin,
            outcome: outcome,
            startedAt: session.startedAt,
            endedAt: endedAt,
            plannedDuration: session.plannedDuration,
            activeDuration: activeDuration,
            scheduledAt: session.scheduledAt,
            cyclePosition: session.cyclePosition
        )
    }

    private func finalize(
        _ session: PausedSession,
        outcome: SessionOutcome,
        endedAt: Date,
        activeDuration: TimeInterval
    ) {
        finalize(
            id: session.id,
            mode: session.mode,
            origin: session.origin,
            outcome: outcome,
            startedAt: session.startedAt,
            endedAt: endedAt,
            plannedDuration: session.plannedDuration,
            activeDuration: activeDuration,
            scheduledAt: session.scheduledAt,
            cyclePosition: session.cyclePosition
        )
    }

    private func finalize(
        id: UUID,
        mode: SessionMode,
        origin: SessionOrigin,
        outcome: SessionOutcome,
        startedAt: Date,
        endedAt: Date,
        plannedDuration: TimeInterval,
        activeDuration: TimeInterval,
        scheduledAt: Date?,
        cyclePosition: Int?
    ) {
        guard finalizedSessionIDs.insert(id).inserted else { return }
        analyticsRecorder.record(
            SessionRecordSnapshot(
                id: id,
                mode: mode,
                origin: origin,
                outcome: outcome,
                startedAt: startedAt,
                endedAt: endedAt,
                plannedDuration: plannedDuration,
                activeDuration: min(plannedDuration, max(0, activeDuration)),
                scheduledAt: scheduledAt,
                cyclePosition: cyclePosition
            )
        )
    }

    private func schedule(every interval: TimeInterval) {
        scheduler.schedule(every: interval) { [weak self] in
            self?.handleTick()
        }
    }

    private func playSound(_ event: SoundEvent) {
        guard settings.enableSounds else { return }
        soundPlayer.play(event)
    }

    private func refreshNow() {
        nowSnapshot = clock.now
    }
}

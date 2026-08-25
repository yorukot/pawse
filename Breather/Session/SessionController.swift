import Foundation
import Observation

@MainActor
@Observable
final class SessionController {
    private(set) var state: SessionState = .idle(selectedMode: .focus)
    private(set) var nowSnapshot: Date
    private(set) var modeSwitchTarget: SessionMode?
    private(set) var isEmergencyExitConfirmationPresented = false
    private(set) var lastError: String?

    let settings: SettingsStore
    private let clock: SessionClock
    private let scheduler: RepeatingScheduling
    private let activityMonitor: UserActivityMonitoring
    private let soundPlayer: SoundPlaying
    private let analyticsRecorder: SessionRecording
    private let breakEnvironment: BreakEnvironmentManaging

    private var entryActivityBaseline: UInt64?
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

    var currentMode: SessionMode { state.selectedOrCurrentMode }

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
    }

    func stopCurrentSession() {
        let now = clock.now
        switch state {
        case .running(let session) where session.mode == .focus:
            finalize(session, outcome: .stopped, endedAt: now, activeDuration: session.activeDuration(at: now))
            scheduler.cancel()
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
        modeSwitchTarget = nil
        state = .idle(selectedMode: target)
        startSession(mode: target, origin: .manual, scheduledAt: nil, cyclePosition: nil)
    }

    func startPendingBreakNow() {
        guard case .breakPending(let pending) = state else { return }
        beginBreakEntry(pending)
    }

    func cancelPendingBreak() {
        guard case .breakPending = state else { return }
        cleanupBreakEnvironment()
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
        cleanupBreakEnvironment()
        state = .idle(selectedMode: .focus)
        nowSnapshot = now
    }

    func handleTick() {
        let now = clock.now
        nowSnapshot = now
        switch state {
        case .running(let session) where now >= session.deadline:
            completeRunningSession(session, at: now)
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

    func cleanupBreakEnvironment() {
        scheduler.cancel()
        breakEnvironment.cleanup()
        soundPlayer.stopAll()
        entryActivityBaseline = nil
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
            cleanupBreakEnvironment()
            lastError = "Breather could not keep every display covered. The break was canceled for safety."
            state = .idle(selectedMode: .focus)
            nowSnapshot = now
        case .breakEntering:
            cleanupBreakEnvironment()
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
        cleanupBreakEnvironment()
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
    }

    private func completeRunningSession(_ session: RunningSession, at now: Date) {
        guard !finalizedSessionIDs.contains(session.id) else { return }
        finalize(session, outcome: .completed, endedAt: now, activeDuration: session.plannedDuration)
        if session.mode == .focus {
            completeFocus(at: now)
        } else {
            completeBreak(session, at: now)
        }
    }

    private func completeFocus(at now: Date) {
        scheduler.cancel()
        settings.focusCycleCount += 1
        let breakMode: SessionMode = settings.focusCycleCount >= settings.longBreakEvery ? .longBreak : .shortBreak
        let duration = settings.duration(for: breakMode)

        guard settings.automaticallyStartBreaks else {
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
            breakEnvironment.showReminder(for: breakMode)
            playSound(.breakReady(breakMode))
            schedule(every: 0.25)
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
        breakEnvironment.showReminder(for: pending.mode)
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
        cleanupBreakEnvironment()
        lastError = "Breather could not cover every display. The break was canceled for safety."
        state = .idle(selectedMode: .focus)
        refreshNow()
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

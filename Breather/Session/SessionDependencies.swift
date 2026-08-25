import Foundation

struct UserActivitySample: Equatable, Sendable {
    let secondsSinceLastInput: TimeInterval
    let activityToken: UInt64
}

protocol UserActivityMonitoring: AnyObject {
    func sample() -> UserActivitySample
}

final class DormantUserActivityMonitor: UserActivityMonitoring {
    func sample() -> UserActivitySample {
        UserActivitySample(secondsSinceLastInput: 0, activityToken: 0)
    }
}

enum SoundEvent: Equatable, Sendable {
    case sessionStarted(SessionMode)
    case breakReady(SessionMode)
    case breakStarted(SessionMode)
    case focusCompleted
    case breakCompleted(SessionMode)
}

@MainActor
protocol SoundPlaying: AnyObject {
    func play(_ event: SoundEvent)
    func stopAll()
}

@MainActor
final class NoOpSoundPlayer: SoundPlaying {
    func play(_ event: SoundEvent) {}
    func stopAll() {}
}

struct SessionRecordSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let mode: SessionMode
    let origin: SessionOrigin
    let outcome: SessionOutcome
    let startedAt: Date
    let endedAt: Date
    let plannedDuration: TimeInterval
    let activeDuration: TimeInterval
    let scheduledAt: Date?
    let cyclePosition: Int?
}

@MainActor
protocol SessionRecording: AnyObject {
    func record(_ session: SessionRecordSnapshot)
}

@MainActor
final class InMemorySessionRecorder: SessionRecording {
    private(set) var records: [SessionRecordSnapshot] = []

    func record(_ session: SessionRecordSnapshot) {
        guard !records.contains(where: { $0.id == session.id }) else { return }
        records.append(session)
    }
}

enum BreakEnvironmentError: Error {
    case overlayCreationFailed
}

@MainActor
protocol BreakEnvironmentManaging: AnyObject {
    func showReminder(_ presentation: BreakReminderPresentation)
    func hideReminder()
    func showEntryOverlays(for mode: SessionMode) throws
    func commitPresentation()
    func cleanup(animated: Bool)
}

@MainActor
final class NoOpBreakEnvironment: BreakEnvironmentManaging {
    func showReminder(_ presentation: BreakReminderPresentation) {}
    func hideReminder() {}
    func showEntryOverlays(for mode: SessionMode) throws {}
    func commitPresentation() {}
    func cleanup(animated: Bool) {}
}

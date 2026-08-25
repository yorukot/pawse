import Foundation

enum SessionOrigin: String, Codable, Sendable {
    case manual
    case automatic
}

enum SessionOutcome: String, Codable, Sendable {
    case completed
    case stopped
    case switchedMode
    case emergencyExit
}

struct RunningSession: Equatable, Sendable {
    let id: UUID
    let mode: SessionMode
    let origin: SessionOrigin
    let startedAt: Date
    let scheduledAt: Date?
    let plannedDuration: TimeInterval
    let deadline: Date
    let activeStartedAt: Date
    let accumulatedActiveDuration: TimeInterval
    let cyclePosition: Int?

    func remaining(at date: Date) -> TimeInterval {
        max(0, deadline.timeIntervalSince(date))
    }

    func activeDuration(at date: Date) -> TimeInterval {
        min(plannedDuration, accumulatedActiveDuration + max(0, date.timeIntervalSince(activeStartedAt)))
    }
}

struct PausedSession: Equatable, Sendable {
    let id: UUID
    let mode: SessionMode
    let origin: SessionOrigin
    let startedAt: Date
    let scheduledAt: Date?
    let plannedDuration: TimeInterval
    let remainingDuration: TimeInterval
    let accumulatedActiveDuration: TimeInterval
    let cyclePosition: Int?
}

struct PendingBreak: Equatable, Sendable {
    let id: UUID
    let mode: SessionMode
    let scheduledAt: Date
    let origin: SessionOrigin
    let cyclePosition: Int?
    let plannedDuration: TimeInterval
}

struct BreakEntry: Equatable, Sendable {
    let id: UUID
    let mode: SessionMode
    let scheduledAt: Date
    let beganEnteringAt: Date
    let origin: SessionOrigin
    let cyclePosition: Int?
    let plannedDuration: TimeInterval
}

enum SessionState: Equatable, Sendable {
    case idle(selectedMode: SessionMode)
    case running(RunningSession)
    case paused(PausedSession)
    case breakPending(PendingBreak)
    case breakEntering(BreakEntry)

    var selectedOrCurrentMode: SessionMode {
        switch self {
        case .idle(let mode): mode
        case .running(let session): session.mode
        case .paused(let session): session.mode
        case .breakPending(let pending): pending.mode
        case .breakEntering(let entry): entry.mode
        }
    }
}

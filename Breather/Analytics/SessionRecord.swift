import Foundation
import SwiftData

@Model
final class SessionRecord {
    @Attribute(.unique) var id: UUID
    var modeRawValue: String
    var originRawValue: String
    var outcomeRawValue: String
    var startedAt: Date
    var endedAt: Date
    var plannedDuration: TimeInterval
    var activeDuration: TimeInterval
    var scheduledAt: Date?
    var cyclePosition: Int?

    init(snapshot: SessionRecordSnapshot) {
        id = snapshot.id
        modeRawValue = snapshot.mode.rawValue
        originRawValue = snapshot.origin.rawValue
        outcomeRawValue = snapshot.outcome.rawValue
        startedAt = snapshot.startedAt
        endedAt = snapshot.endedAt
        plannedDuration = snapshot.plannedDuration
        activeDuration = snapshot.activeDuration
        scheduledAt = snapshot.scheduledAt
        cyclePosition = snapshot.cyclePosition
    }

    var snapshot: SessionRecordSnapshot {
        SessionRecordSnapshot(
            id: id,
            mode: SessionMode(rawValue: modeRawValue) ?? .focus,
            origin: SessionOrigin(rawValue: originRawValue) ?? .manual,
            outcome: SessionOutcome(rawValue: outcomeRawValue) ?? .stopped,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedDuration: plannedDuration,
            activeDuration: activeDuration,
            scheduledAt: scheduledAt,
            cyclePosition: cyclePosition
        )
    }
}

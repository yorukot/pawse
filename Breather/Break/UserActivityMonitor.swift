import CoreGraphics
import Foundation

final class SystemUserActivityMonitor: UserActivityMonitoring {
    private let anyInputEvent = CGEventType(rawValue: UInt32.max)
    private let countedEventTypes: [CGEventType] = [
        .keyDown,
        .keyUp,
        .flagsChanged,
        .mouseMoved,
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .rightMouseUp,
        .otherMouseDown,
        .otherMouseUp,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged,
        .scrollWheel
    ]

    func sample() -> UserActivitySample {
        let idleDuration: TimeInterval
        if let anyInputEvent {
            idleDuration = CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: anyInputEvent
            )
        } else {
            idleDuration = 0
        }

        var token: UInt64 = 14_695_981_039_346_656_037
        for eventType in countedEventTypes {
            let counter = CGEventSource.counterForEventType(
                .combinedSessionState,
                eventType: eventType
            )
            token ^= UInt64(counter)
            token &*= 1_099_511_628_211
        }

        return UserActivitySample(
            secondsSinceLastInput: max(0, idleDuration),
            activityToken: token
        )
    }
}

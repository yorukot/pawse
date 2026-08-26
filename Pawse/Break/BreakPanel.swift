import AppKit

final class BreakPanel: NSPanel {
    var onDiscreetActivity: (@MainActor () -> Void)?
    var isDiscreetInputArmed = false
    private(set) var isDiscreetMode = false

    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setDiscreetMode(_ isDiscreet: Bool) {
        isDiscreetMode = isDiscreet
        isOpaque = !isDiscreet
        backgroundColor = isDiscreet ? .clear : .black
    }

    override func sendEvent(_ event: NSEvent) {
        if isDiscreetMode, Self.isDiscreetActivity(event.type) {
            if isDiscreetInputArmed {
                isDiscreetInputArmed = false
                onDiscreetActivity?()
            }
            // Consume input during the arming delay too, so a key equivalent
            // or click cannot leak through the transparent break surface.
            return
        }
        super.sendEvent(event)
    }

    static func isDiscreetActivity(_ eventType: NSEvent.EventType) -> Bool {
        switch eventType {
        case .keyDown,
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
             .scrollWheel,
             .gesture,
             .magnify,
             .swipe,
             .rotate,
             .beginGesture,
             .endGesture,
             .smartMagnify,
             .pressure,
             .directTouch:
            true
        default:
            false
        }
    }
}

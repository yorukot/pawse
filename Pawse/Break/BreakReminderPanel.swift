import AppKit
import SwiftUI

final class BreakReminderPanel: NSPanel {
    static let reminderSize = NSSize(width: 336, height: 112)

    private let materialView: NSVisualEffectView
    private weak var hostedView: NSView?

    init() {
        let materialView = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.reminderSize))
        materialView.material = .hudWindow
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = PawseTheme.Metrics.reminderCornerRadius
        materialView.layer?.cornerCurve = .continuous
        materialView.layer?.masksToBounds = true
        self.materialView = materialView

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.reminderSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        animationBehavior = .none
        contentView = materialView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    var usesHUDMaterial: Bool {
        materialView.material == .hudWindow
    }

    var hostedContentViewCount: Int {
        hostedView?.superview === materialView ? 1 : 0
    }

    func installHostedView(_ view: NSView) {
        hostedView?.removeFromSuperview()
        hostedView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        materialView.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: materialView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: materialView.trailingAnchor),
            view.topAnchor.constraint(equalTo: materialView.topAnchor),
            view.bottomAnchor.constraint(equalTo: materialView.bottomAnchor)
        ])
    }

    func clearHostedView() {
        hostedView?.removeFromSuperview()
        hostedView = nil
    }
}

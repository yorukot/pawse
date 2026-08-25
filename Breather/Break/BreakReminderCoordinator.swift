import AppKit
import SwiftUI

@MainActor
final class BreakReminderCoordinator: NSObject {
    var onStartBreak: (@MainActor () -> Void)?

    private var panel: BreakReminderPanel?
    private var isMonitoringScreens = false

    var isVisible: Bool { panel?.isVisible == true }
    var isKeyWindow: Bool { panel?.isKeyWindow == true }
    var panelSize: NSSize? { panel?.frame.size }
    var usesHUDMaterial: Bool { panel?.usesHUDMaterial == true }
    var hostedContentViewCount: Int { panel?.hostedContentViewCount ?? 0 }

    func show(for mode: SessionMode, scheduledAt: Date = .now) {
        if let panel {
            panel.installHostedView(hostingView(for: mode, scheduledAt: scheduledAt))
            reposition(panel)
            panel.orderFrontRegardless()
            return
        }

        let panel = BreakReminderPanel()
        panel.installHostedView(hostingView(for: mode, scheduledAt: scheduledAt))
        self.panel = panel
        reposition(panel)
        startMonitoringScreens()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.clearHostedView()
        panel = nil
        stopMonitoringScreens()
    }

    private func hostingView(for mode: SessionMode, scheduledAt: Date) -> NSHostingView<BreakReminderView> {
        NSHostingView(
            rootView: BreakReminderView(mode: mode, scheduledAt: scheduledAt) { [weak self] in
                self?.onStartBreak?()
            }
        )
    }

    private func reposition(_ panel: NSPanel) {
        guard let screen = NSScreen.screens.first ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.maxY - panel.frame.height - 18
        )
        panel.setFrameOrigin(origin)
    }

    private func startMonitoringScreens() {
        guard !isMonitoringScreens else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        isMonitoringScreens = true
    }

    private func stopMonitoringScreens() {
        guard isMonitoringScreens else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        isMonitoringScreens = false
    }

    @objc private func screenParametersChanged() {
        guard let panel else { return }
        reposition(panel)
        panel.orderFrontRegardless()
    }
}

import AppKit
import SwiftUI

@MainActor
final class BreakReminderCoordinator: NSObject {
    var onStartBreak: (@MainActor () -> Void)?

    private var panel: BreakReminderPanel?
    private var isMonitoringScreens = false

    func show(for mode: SessionMode) {
        if let panel {
            panel.contentView = hostingView(for: mode)
            reposition(panel)
            panel.orderFrontRegardless()
            return
        }

        let panel = BreakReminderPanel()
        panel.contentView = hostingView(for: mode)
        self.panel = panel
        reposition(panel)
        startMonitoringScreens()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        stopMonitoringScreens()
    }

    private func hostingView(for mode: SessionMode) -> NSHostingView<BreakReminderView> {
        NSHostingView(
            rootView: BreakReminderView(mode: mode) { [weak self] in
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

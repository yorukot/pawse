import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class OverlayCoordinator {
    var onSynchronizationFailure: (@MainActor () -> Void)?

    private let settings: SettingsStore
    private let screenChangeMonitor: ScreenChangeMonitor
    private weak var controller: SessionController?
    private var panels: [CGDirectDisplayID: BreakPanel] = [:]
    private var activeMode: SessionMode?

    init(
        settings: SettingsStore,
        screenChangeMonitor: ScreenChangeMonitor = ScreenChangeMonitor()
    ) {
        self.settings = settings
        self.screenChangeMonitor = screenChangeMonitor
        screenChangeMonitor.onChange = { [weak self] in
            self?.handleScreenChange()
        }
    }

    var panelCount: Int { panels.count }

    func connect(controller: SessionController) {
        self.controller = controller
    }

    func show(for mode: SessionMode) throws {
        guard controller != nil else { throw BreakEnvironmentError.overlayCreationFailed }
        activeMode = mode
        do {
            try synchronizePanels()
            screenChangeMonitor.start()
            panels.values.forEach { $0.orderFrontRegardless() }
        } catch {
            cleanup()
            throw error
        }
    }

    func cleanup() {
        screenChangeMonitor.stop()
        for panel in panels.values {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        panels.removeAll()
        activeMode = nil
    }

    private func handleScreenChange() {
        do {
            try synchronizePanels()
            panels.values.forEach { $0.orderFrontRegardless() }
        } catch {
            cleanup()
            onSynchronizationFailure?()
        }
    }

    private func synchronizePanels() throws {
        guard let mode = activeMode, let controller else {
            throw BreakEnvironmentError.overlayCreationFailed
        }

        var currentScreens: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            guard let displayID = Self.displayID(for: screen) else {
                throw BreakEnvironmentError.overlayCreationFailed
            }
            currentScreens[displayID] = screen
        }
        guard !currentScreens.isEmpty else {
            throw BreakEnvironmentError.overlayCreationFailed
        }

        let removedIDs = Set(panels.keys).subtracting(currentScreens.keys)
        for displayID in removedIDs {
            panels[displayID]?.orderOut(nil)
            panels[displayID]?.contentView = nil
            panels[displayID]?.close()
            panels.removeValue(forKey: displayID)
        }

        for (displayID, screen) in currentScreens {
            if let panel = panels[displayID] {
                panel.setFrame(screen.frame, display: true)
            } else {
                let panel = BreakPanel(frame: screen.frame)
                panel.contentView = NSHostingView(
                    rootView: BreakOverlayView(
                        mode: mode,
                        controller: controller,
                        settings: settings
                    )
                )
                panel.setFrame(screen.frame, display: true)
                panels[displayID] = panel
            }
        }

        guard panels.count == currentScreens.count else {
            throw BreakEnvironmentError.overlayCreationFailed
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }
}

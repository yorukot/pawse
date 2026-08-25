import AppKit
import CoreGraphics
import QuartzCore
import SwiftUI

@MainActor
final class OverlayCoordinator {
    var onSynchronizationFailure: (@MainActor () -> Void)?

    private let settings: SettingsStore
    private let backgroundProvider: BreakBackgroundProviding
    private let screenChangeMonitor: ScreenChangeMonitor
    private let locale: Locale
    private weak var controller: SessionController?
    private var panels: [CGDirectDisplayID: BreakPanel] = [:]
    private var fadingPanels: [ObjectIdentifier: BreakPanel] = [:]
    private var activeMode: SessionMode?

    init(
        settings: SettingsStore,
        backgroundProvider: BreakBackgroundProviding? = nil,
        locale: Locale = .autoupdatingCurrent,
        screenChangeMonitor: ScreenChangeMonitor = ScreenChangeMonitor()
    ) {
        self.settings = settings
        self.backgroundProvider = backgroundProvider ?? BreakBackgroundService(settings: settings)
        self.locale = locale
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
        closeFadingPanels()
        activeMode = mode
        backgroundProvider.resetCache()
        do {
            try synchronizePanels()
            screenChangeMonitor.start()
            panels.values.forEach { $0.orderFrontRegardless() }
            fadeInPanelsIfNeeded()
        } catch {
            cleanup(animated: false)
            throw error
        }
    }

    func cleanup(animated: Bool = true) {
        screenChangeMonitor.stop()
        let panelsToClose = Array(panels.values)
        panels.removeAll()
        activeMode = nil
        backgroundProvider.resetCache()

        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            closeFadingPanels()
            panelsToClose.forEach(Self.close)
            return
        }

        for panel in panelsToClose {
            fadingPanels[ObjectIdentifier(panel)] = panel
            panel.ignoresMouseEvents = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.6
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard let self else { return }
            for panel in panelsToClose {
                let identifier = ObjectIdentifier(panel)
                guard self.fadingPanels.removeValue(forKey: identifier) != nil else { continue }
                Self.close(panel)
            }
        }
    }

    private func handleScreenChange() {
        do {
            try synchronizePanels()
            panels.values.forEach { $0.orderFrontRegardless() }
            fadeInPanelsIfNeeded()
        } catch {
            cleanup(animated: false)
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
                        settings: settings,
                        backgroundImage: backgroundProvider.image(for: screen)
                    )
                    .environment(\.locale, locale)
                )
                panel.alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
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

    private func fadeInPanelsIfNeeded() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        for panel in panels.values where panel.alphaValue < 1 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.6
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    private static func close(_ panel: BreakPanel) {
        panel.orderOut(nil)
        panel.contentView = nil
        panel.close()
    }

    private func closeFadingPanels() {
        let panelsToClose = Array(fadingPanels.values)
        fadingPanels.removeAll()
        panelsToClose.forEach(Self.close)
    }
}

import AppKit
import CoreGraphics
import QuartzCore
import SwiftUI

@MainActor
final class OverlayCoordinator {
    var onSynchronizationFailure: (@MainActor () -> Void)?
    var onDiscreetModeChanged: (@MainActor (Bool) -> Void)?

    private let settings: SettingsStore
    private let backgroundProvider: BreakBackgroundProviding
    private let presentationState: BreakPresentationState
    private let screenChangeMonitor: ScreenChangeMonitor
    private let locale: Locale
    private let discreetArmDelay: Duration
    private weak var controller: SessionController?
    private var panels: [CGDirectDisplayID: BreakPanel] = [:]
    private var fadingPanels: [ObjectIdentifier: BreakPanel] = [:]
    private var activeMode: SessionMode?
    private var discreetArmTask: Task<Void, Never>?

    init(
        settings: SettingsStore,
        backgroundProvider: BreakBackgroundProviding? = nil,
        presentationState: BreakPresentationState = BreakPresentationState(),
        locale: Locale = .autoupdatingCurrent,
        screenChangeMonitor: ScreenChangeMonitor = ScreenChangeMonitor(),
        discreetArmDelay: Duration = .seconds(1)
    ) {
        self.settings = settings
        self.backgroundProvider = backgroundProvider ?? BreakBackgroundService(settings: settings)
        self.presentationState = presentationState
        self.locale = locale
        self.screenChangeMonitor = screenChangeMonitor
        self.discreetArmDelay = discreetArmDelay
        screenChangeMonitor.onChange = { [weak self] in
            self?.handleScreenChange()
        }
    }

    var panelCount: Int { panels.count }
    var discreetPanelCount: Int { panels.values.count(where: \.isDiscreetMode) }
    var armedDiscreetPanelCount: Int {
        panels.values.count { $0.isDiscreetMode && $0.isDiscreetInputArmed }
    }

    func connect(controller: SessionController) {
        self.controller = controller
    }

    func show(for mode: SessionMode) throws {
        guard controller != nil else { throw BreakEnvironmentError.overlayCreationFailed }
        discreetArmTask?.cancel()
        discreetArmTask = nil
        closeFadingPanels()
        activeMode = mode
        presentationState.beginBreakEntry()
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
        discreetArmTask?.cancel()
        discreetArmTask = nil
        screenChangeMonitor.stop()
        let panelsToClose = Array(panels.values)
        panels.removeAll()
        activeMode = nil
        presentationState.reset()
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
            if presentationState.isDiscreet {
                focusPanelForDiscreetInput()
            }
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
                configureDiscreetBehavior(for: panel)
            } else {
                let panel = BreakPanel(frame: screen.frame)
                configureDiscreetBehavior(for: panel)
                panel.contentView = NSHostingView(
                    rootView: BreakOverlayView(
                        mode: mode,
                        controller: controller,
                        settings: settings,
                        backgroundImage: backgroundProvider.image(for: screen),
                        presentationState: presentationState,
                        onEnterDiscreetMode: { [weak self] in
                            self?.activateDiscreetMode()
                        }
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

    func commitBreak() {
        guard activeMode != nil else { return }
        presentationState.commitBreak()
        if settings.startBreaksInDiscreetMode {
            activateDiscreetMode()
        }
    }

    func activateDiscreetMode() {
        guard activeMode != nil,
              presentationState.isBreakCommitted,
              !presentationState.isDiscreet else { return }

        discreetArmTask?.cancel()
        panels.values.forEach {
            $0.isDiscreetInputArmed = false
            $0.setDiscreetMode(true)
        }
        presentationState.beginDiscreetMode()
        onDiscreetModeChanged?(true)
        focusPanelForDiscreetInput()

        discreetArmTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: discreetArmDelay)
            } catch {
                return
            }
            guard presentationState.phase == .discreetPreparing,
                  activeMode != nil else { return }
            presentationState.armDiscreetMode()
            panels.values.forEach { $0.isDiscreetInputArmed = true }
            discreetArmTask = nil
        }
    }

    func revealDiscreetBreak() {
        guard presentationState.isDiscreet else { return }
        discreetArmTask?.cancel()
        discreetArmTask = nil
        panels.values.forEach {
            $0.isDiscreetInputArmed = false
            $0.setDiscreetMode(false)
            $0.orderFrontRegardless()
        }
        presentationState.revealBreak()
        onDiscreetModeChanged?(false)
    }

    private func configureDiscreetBehavior(for panel: BreakPanel) {
        panel.onDiscreetActivity = { [weak self] in
            self?.revealDiscreetBreak()
        }
        panel.setDiscreetMode(presentationState.isDiscreet)
        panel.isDiscreetInputArmed = presentationState.isInputArmed
    }

    private func focusPanelForDiscreetInput() {
        NSApp.activate(ignoringOtherApps: true)
        let mainDisplayID = NSScreen.main.flatMap(Self.displayID(for:))
        let keyPanel = mainDisplayID.flatMap { panels[$0] } ?? panels.values.first
        keyPanel?.makeKeyAndOrderFront(nil)
        panels.values
            .filter { $0 !== keyPanel }
            .forEach { $0.orderFrontRegardless() }
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
        panel.onDiscreetActivity = nil
        panel.isDiscreetInputArmed = false
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

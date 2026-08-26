import Foundation

@MainActor
final class BreakEnvironmentCoordinator: BreakEnvironmentManaging {
    var onStartBreak: (@MainActor () -> Void)? {
        didSet { reminderCoordinator.onStartBreak = onStartBreak }
    }

    private let reminderCoordinator: BreakReminderCoordinator
    private let overlayCoordinator: OverlayCoordinator
    private let presentationController: PresentationOptionsController

    init(
        settings: SettingsStore,
        backgroundProvider: BreakBackgroundProviding,
        presentationState: BreakPresentationState = BreakPresentationState(),
        locale: Locale = .autoupdatingCurrent,
        reminderCoordinator: BreakReminderCoordinator? = nil,
        presentationController: PresentationOptionsController = PresentationOptionsController()
    ) {
        let overlayCoordinator = OverlayCoordinator(
            settings: settings,
            backgroundProvider: backgroundProvider,
            presentationState: presentationState,
            locale: locale
        )
        self.reminderCoordinator = reminderCoordinator ?? BreakReminderCoordinator(locale: locale)
        self.overlayCoordinator = overlayCoordinator
        self.presentationController = presentationController
        overlayCoordinator.onDiscreetModeChanged = { [weak presentationController] isDiscreet in
            if isDiscreet {
                presentationController?.applyForDiscreetBreak()
            } else {
                presentationController?.applyForCommittedBreak()
            }
        }
    }

    func connect(controller: SessionController) {
        overlayCoordinator.connect(controller: controller)
        overlayCoordinator.onSynchronizationFailure = { [weak controller] in
            controller?.handleBreakEnvironmentFailure()
        }
    }

    func showReminder(_ presentation: BreakReminderPresentation) {
        reminderCoordinator.show(presentation)
    }

    func hideReminder() {
        reminderCoordinator.hide()
    }

    func showEntryOverlays(for mode: SessionMode) throws {
        reminderCoordinator.hide()
        try overlayCoordinator.show(for: mode)
    }

    func commitPresentation() {
        presentationController.applyForCommittedBreak()
        overlayCoordinator.commitBreak()
    }

    func cleanup(animated: Bool) {
        reminderCoordinator.hide()
        overlayCoordinator.cleanup(animated: animated)
        presentationController.restore()
    }
}

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
        reminderCoordinator: BreakReminderCoordinator = BreakReminderCoordinator(),
        presentationController: PresentationOptionsController = PresentationOptionsController()
    ) {
        self.reminderCoordinator = reminderCoordinator
        overlayCoordinator = OverlayCoordinator(
            settings: settings,
            backgroundProvider: backgroundProvider
        )
        self.presentationController = presentationController
    }

    func connect(controller: SessionController) {
        overlayCoordinator.connect(controller: controller)
        overlayCoordinator.onSynchronizationFailure = { [weak controller] in
            controller?.handleBreakEnvironmentFailure()
        }
    }

    func showReminder(for pendingBreak: PendingBreak) {
        reminderCoordinator.show(
            for: pendingBreak.mode,
            scheduledAt: pendingBreak.scheduledAt
        )
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
    }

    func cleanup(animated: Bool) {
        reminderCoordinator.hide()
        overlayCoordinator.cleanup(animated: animated)
        presentationController.restore()
    }
}

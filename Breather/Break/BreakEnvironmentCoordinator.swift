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
        reminderCoordinator: BreakReminderCoordinator = BreakReminderCoordinator(),
        presentationController: PresentationOptionsController = PresentationOptionsController()
    ) {
        self.reminderCoordinator = reminderCoordinator
        overlayCoordinator = OverlayCoordinator(settings: settings)
        self.presentationController = presentationController
    }

    func connect(controller: SessionController) {
        overlayCoordinator.connect(controller: controller)
        overlayCoordinator.onSynchronizationFailure = { [weak controller] in
            controller?.handleBreakEnvironmentFailure()
        }
    }

    func showReminder(for mode: SessionMode) {
        reminderCoordinator.show(for: mode)
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

    func cleanup() {
        reminderCoordinator.hide()
        overlayCoordinator.cleanup()
        presentationController.restore()
    }
}

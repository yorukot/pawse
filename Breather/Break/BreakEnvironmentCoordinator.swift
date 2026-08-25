import Foundation

@MainActor
final class BreakEnvironmentCoordinator: BreakEnvironmentManaging {
    var onStartBreak: (@MainActor () -> Void)? {
        didSet { reminderCoordinator.onStartBreak = onStartBreak }
    }

    private let reminderCoordinator: BreakReminderCoordinator

    init(reminderCoordinator: BreakReminderCoordinator = BreakReminderCoordinator()) {
        self.reminderCoordinator = reminderCoordinator
    }

    func showReminder(for mode: SessionMode) {
        reminderCoordinator.show(for: mode)
    }

    func hideReminder() {
        reminderCoordinator.hide()
    }

    func showEntryOverlays(for mode: SessionMode) throws {
        reminderCoordinator.hide()
    }

    func commitPresentation() {}

    func cleanup() {
        reminderCoordinator.hide()
    }
}

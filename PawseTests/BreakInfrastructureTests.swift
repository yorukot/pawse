import AppKit
import XCTest
@testable import Breather

@MainActor
final class BreakInfrastructureTests: XCTestCase {
    func testReminderPanelIsVisibleClickableAndDoesNotBecomeKey() {
        let coordinator = BreakReminderCoordinator()
        var clicked = false
        coordinator.onStartBreak = { clicked = true }

        coordinator.show(
            BreakReminderPresentation(
                mode: .shortBreak,
                phase: .upcoming(deadline: .now.addingTimeInterval(10), leadTime: 10)
            )
        )
        XCTAssertTrue(coordinator.isVisible)
        XCTAssertFalse(coordinator.isKeyWindow)
        XCTAssertEqual(coordinator.panelSize, BreakReminderPanel.reminderSize)
        XCTAssertTrue(coordinator.usesHUDMaterial)
        XCTAssertEqual(coordinator.hostedContentViewCount, 1)
        XCTAssertFalse(clicked)

        coordinator.show(
            BreakReminderPresentation(mode: .longBreak, phase: .ready(scheduledAt: .now))
        )
        XCTAssertEqual(coordinator.hostedContentViewCount, 1)

        coordinator.hide()
        XCTAssertFalse(coordinator.isVisible)
        XCTAssertEqual(coordinator.hostedContentViewCount, 0)
    }

    func testOverlayCoordinatorCreatesOnePanelPerConnectedDisplayAndCleansReferences() throws {
        let harness = ControllerHarness()
        let coordinator = OverlayCoordinator(settings: harness.settings)
        coordinator.connect(controller: harness.controller)

        try coordinator.show(for: .shortBreak)
        XCTAssertEqual(coordinator.panelCount, NSScreen.screens.count)
        XCTAssertGreaterThan(coordinator.panelCount, 0)

        coordinator.cleanup()
        coordinator.cleanup()
        XCTAssertEqual(coordinator.panelCount, 0)
    }

    func testPresentationOptionsRestoreExactlyAndIdempotently() {
        let previous = NSApplication.shared.presentationOptions
        let controller = PresentationOptionsController()
        defer {
            controller.restore()
            NSApplication.shared.presentationOptions = previous
        }

        controller.applyForCommittedBreak()
        controller.applyForCommittedBreak()
        XCTAssertTrue(controller.isApplied)

        controller.restore()
        controller.restore()
        XCTAssertFalse(controller.isApplied)
        XCTAssertEqual(NSApplication.shared.presentationOptions, previous)
    }

    func testSystemActivitySampleIsAggregateAndNonnegative() {
        let sample = SystemUserActivityMonitor().sample()
        XCTAssertGreaterThanOrEqual(sample.secondsSinceLastInput, 0)
    }
}

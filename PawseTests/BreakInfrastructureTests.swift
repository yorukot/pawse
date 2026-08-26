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

        coordinator.cleanup(animated: false)
        coordinator.cleanup(animated: false)
        XCTAssertEqual(coordinator.panelCount, 0)
    }

    func testBreakPresentationStateOnlyAllowsDiscreetModeAfterCommit() {
        let state = BreakPresentationState()

        state.beginDiscreetMode()
        XCTAssertEqual(state.phase, .visible)

        state.commitBreak()
        state.beginDiscreetMode()
        XCTAssertEqual(state.phase, .discreetPreparing)
        XCTAssertTrue(state.isDiscreet)
        XCTAssertFalse(state.isInputArmed)

        state.armDiscreetMode()
        XCTAssertEqual(state.phase, .discreetArmed)
        XCTAssertTrue(state.isInputArmed)

        state.revealBreak()
        XCTAssertEqual(state.phase, .visible)
        XCTAssertTrue(state.isBreakCommitted)

        state.reset()
        XCTAssertFalse(state.isBreakCommitted)
        XCTAssertFalse(state.isDiscreet)
    }

    func testOverlayCoordinatorArmsRevealsAndCanReenterDiscreetMode() async throws {
        let harness = ControllerHarness()
        let presentationState = BreakPresentationState()
        let coordinator = OverlayCoordinator(
            settings: harness.settings,
            presentationState: presentationState,
            discreetArmDelay: .milliseconds(1)
        )
        coordinator.connect(controller: harness.controller)
        defer { coordinator.cleanup(animated: false) }

        try coordinator.show(for: .shortBreak)
        coordinator.commitBreak()
        coordinator.activateDiscreetMode()

        XCTAssertEqual(coordinator.discreetPanelCount, NSScreen.screens.count)
        XCTAssertEqual(presentationState.phase, .discreetPreparing)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(presentationState.phase, .discreetArmed)
        XCTAssertEqual(coordinator.armedDiscreetPanelCount, NSScreen.screens.count)

        coordinator.revealDiscreetBreak()
        XCTAssertEqual(presentationState.phase, .visible)
        XCTAssertEqual(coordinator.discreetPanelCount, 0)

        coordinator.activateDiscreetMode()
        XCTAssertTrue(presentationState.isDiscreet)
        XCTAssertEqual(coordinator.discreetPanelCount, NSScreen.screens.count)
    }

    func testCommittedBreakStartsDiscreetWhenPreferenceIsEnabled() throws {
        let harness = ControllerHarness { settings in
            settings.startBreaksInDiscreetMode = true
        }
        let presentationState = BreakPresentationState()
        let coordinator = OverlayCoordinator(
            settings: harness.settings,
            presentationState: presentationState
        )
        coordinator.connect(controller: harness.controller)
        defer { coordinator.cleanup(animated: false) }

        try coordinator.show(for: .longBreak)
        XCTAssertFalse(presentationState.isDiscreet)

        coordinator.commitBreak()

        XCTAssertEqual(presentationState.phase, .discreetPreparing)
        XCTAssertEqual(coordinator.discreetPanelCount, NSScreen.screens.count)
    }

    func testBreakPanelClassifiesInputThatShouldRevealTheBreak() {
        let discreetActivity: [NSEvent.EventType] = [
            .keyDown,
            .flagsChanged,
            .mouseMoved,
            .leftMouseDown,
            .leftMouseDragged,
            .scrollWheel,
            .magnify,
            .swipe
        ]

        for eventType in discreetActivity {
            XCTAssertTrue(BreakPanel.isDiscreetActivity(eventType), "Expected \(eventType) to reveal")
        }
        XCTAssertFalse(BreakPanel.isDiscreetActivity(.applicationDefined))
    }

    func testBreakPanelConsumesInputDuringDelayAndRevealsAfterArming() throws {
        let panel = BreakPanel(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        defer { panel.close() }
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "a",
                charactersIgnoringModifiers: "a",
                isARepeat: false,
                keyCode: 0
            )
        )
        var revealCount = 0
        panel.onDiscreetActivity = { revealCount += 1 }
        panel.setDiscreetMode(true)

        panel.sendEvent(event)
        XCTAssertEqual(revealCount, 0)

        panel.isDiscreetInputArmed = true
        panel.sendEvent(event)
        XCTAssertEqual(revealCount, 1)
        XCTAssertFalse(panel.isDiscreetInputArmed)

        panel.sendEvent(event)
        XCTAssertEqual(revealCount, 1)
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
        var committedOptions = previous
        committedOptions.remove([.autoHideDock, .autoHideMenuBar])
        committedOptions.formUnion([.hideDock, .hideMenuBar, .disableProcessSwitching])
        XCTAssertEqual(NSApplication.shared.presentationOptions, committedOptions)

        controller.applyForDiscreetBreak()
        var discreetOptions = previous
        if discreetOptions.isDisjoint(with: [.hideDock, .autoHideDock]) {
            discreetOptions.insert(.autoHideDock)
        }
        discreetOptions.insert(.disableProcessSwitching)
        XCTAssertEqual(NSApplication.shared.presentationOptions, discreetOptions)

        controller.applyForCommittedBreak()
        XCTAssertEqual(NSApplication.shared.presentationOptions, committedOptions)

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

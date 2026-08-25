import XCTest
@testable import Breather

@MainActor
final class CleanupTests: XCTestCase {
    func testNormalBreakCompletionRunsCentralCleanupOnce() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.shortBreak)
        harness.controller.startSelectedMode()
        harness.advance(60)

        XCTAssertEqual(harness.environment.cleanupCount, 1)
        XCTAssertEqual(harness.sound.stopCount, 1)
        XCTAssertFalse(harness.scheduler.isScheduled)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .completed)
    }

    func testCentralCleanupIsSafeWhenCalledTwiceWithNoOverlay() {
        let harness = ControllerHarness()
        harness.controller.cleanupBreakEnvironment()
        harness.controller.cleanupBreakEnvironment()

        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .focus))
        XCTAssertEqual(harness.environment.cleanupCount, 2)
        XCTAssertEqual(harness.sound.stopCount, 2)
        XCTAssertTrue(harness.recorder.records.isEmpty)
    }

    func testRepeatedEmergencyAndCleanupCannotDuplicateAnalytics() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.longBreak)
        harness.controller.startSelectedMode()
        harness.controller.requestEmergencyExit()
        harness.controller.confirmEmergencyExit()
        harness.controller.cleanupBreakEnvironment()
        harness.controller.confirmEmergencyExit()

        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .emergencyExit)
    }

    func testTerminationFinalizesRunningFocusAndCleansEnvironment() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(15)
        harness.controller.prepareForTermination()
        harness.controller.prepareForTermination()

        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .stopped)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 15, accuracy: 0.001)
        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .focus))
        XCTAssertGreaterThanOrEqual(harness.environment.cleanupCount, 2)
    }

    func testDisplaySynchronizationFailureFinalizesCommittedBreakOnce() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.shortBreak)
        harness.controller.startSelectedMode()
        harness.advance(5)
        harness.controller.handleBreakEnvironmentFailure()
        harness.controller.handleBreakEnvironmentFailure()

        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .focus))
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .stopped)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 5, accuracy: 0.001)
        XCTAssertEqual(harness.environment.cleanupCount, 1)
    }

    func testEntryFailureDoesNotInventBreakAnalytics() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.environment.shouldFailOverlay = true
        harness.controller.startPendingBreakNow()
        harness.controller.cleanupBreakEnvironment()

        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].mode, .focus)
        XCTAssertEqual(harness.recorder.records[0].outcome, .completed)
    }
}

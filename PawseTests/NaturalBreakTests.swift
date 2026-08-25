import XCTest
@testable import Breather

@MainActor
final class NaturalBreakTests: XCTestCase {
    func testFocusCompletionEntersPendingAndFinalizesFocusOnly() {
        let harness = ControllerHarness()
        harness.completeFocus()

        guard case .breakPending(let pending) = harness.controller.state else {
            return XCTFail("Expected Break Pending")
        }
        XCTAssertEqual(pending.mode, .shortBreak)
        XCTAssertEqual(pending.scheduledAt, harness.clock.now)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].mode, .focus)
        XCTAssertEqual(harness.recorder.records[0].outcome, .completed)
        XCTAssertEqual(harness.settings.focusCycleCount, 1)
        XCTAssertEqual(harness.environment.reminderModes, [.shortBreak])
        XCTAssertEqual(harness.environment.commitPresentationCount, 0)
        XCTAssertEqual(harness.scheduler.interval, 0.25)
    }

    func testBreakReadySoundFiresOnceAndRetryDoesNotReplayIt() {
        let harness = ControllerHarness()
        harness.completeFocus()
        XCTAssertEqual(harness.sound.events.filter { $0 == .breakReady(.shortBreak) }.count, 1)

        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 10)
        harness.controller.handleTick()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 11)
        harness.controller.handleTick()

        XCTAssertEqual(harness.sound.events.filter { $0 == .breakReady(.shortBreak) }.count, 1)
        XCTAssertEqual(harness.environment.reminderModes.count, 2)
    }

    func testContinuousActivityCanDeferBreakWithoutStartingCountdown() {
        let harness = ControllerHarness()
        harness.completeFocus()

        for token in 1...20 {
            harness.activity.current = UserActivitySample(secondsSinceLastInput: 0.2, activityToken: UInt64(token))
            harness.advance(1)
            guard case .breakPending = harness.controller.state else {
                return XCTFail("Activity should keep break pending")
            }
            XCTAssertEqual(harness.controller.remainingTime, 60)
        }
        XCTAssertEqual(harness.environment.overlayModes.count, 0)
        XCTAssertEqual(harness.recorder.records.count, 1)
    }

    func testIdleThresholdBeginsEntryExactlyOnce() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 50)

        harness.controller.handleTick()
        harness.controller.handleTick()

        guard case .breakEntering = harness.controller.state else {
            return XCTFail("Expected Break Entering")
        }
        XCTAssertEqual(harness.environment.overlayModes, [.shortBreak])
        XCTAssertEqual(harness.environment.hideReminderCount, 1)
        XCTAssertEqual(harness.environment.commitPresentationCount, 0)
    }

    func testHUDClickBeginsEntryAndInitiatingClickDoesNotCancelIt() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 99)

        harness.controller.startPendingBreakNow()
        harness.advance(0.5)

        guard case .breakEntering = harness.controller.state else {
            return XCTFail("The initiating click baseline should not cancel entry")
        }
        XCTAssertEqual(harness.environment.overlayModes.count, 1)
    }

    func testNewActivityDuringGraceReturnsToPending() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 7)
        harness.controller.handleTick()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 8)

        harness.advance(1)

        guard case .breakPending = harness.controller.state else {
            return XCTFail("Expected a return to Break Pending")
        }
        XCTAssertEqual(harness.environment.cleanupCount, 1)
        XCTAssertEqual(harness.environment.reminderModes.count, 2)
        XCTAssertEqual(harness.controller.remainingTime, 60)
        XCTAssertEqual(harness.recorder.records.count, 1)
    }

    func testCanceledEntryRequiresFreshIdleIntervalAndRestartsFullDuration() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 1)
        harness.controller.handleTick()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 2)
        harness.advance(1)

        harness.activity.current = UserActivitySample(secondsSinceLastInput: 4.9, activityToken: 2)
        harness.advance(4.9)
        guard case .breakPending = harness.controller.state else {
            return XCTFail("A full new idle threshold is required")
        }

        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 2)
        harness.advance(0.1)
        guard case .breakEntering(let retry) = harness.controller.state else {
            return XCTFail("Expected retry entry")
        }
        XCTAssertEqual(retry.plannedDuration, 60)
        XCTAssertEqual(harness.controller.remainingTime, 60, accuracy: 0.001)
    }

    func testGraceCompletionCommitsBreakAndLaterInputDoesNotDismissIt() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 20)
        harness.controller.handleTick()

        harness.advance(3)
        guard case .running(let running) = harness.controller.state else {
            return XCTFail("Expected committed Break")
        }
        XCTAssertEqual(running.mode, .shortBreak)
        XCTAssertEqual(harness.environment.commitPresentationCount, 1)

        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 21)
        harness.advance(1)
        guard case .running(let stillRunning) = harness.controller.state else {
            return XCTFail("Committed break must ignore ordinary input")
        }
        XCTAssertEqual(stillRunning.id, running.id)
    }

    func testManualBreakSkipsPendingAndCommitsImmediately() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.longBreak)
        harness.controller.startSelectedMode()

        guard case .running(let running) = harness.controller.state else {
            return XCTFail("Expected active manual break")
        }
        XCTAssertEqual(running.mode, .longBreak)
        XCTAssertEqual(running.origin, .manual)
        XCTAssertEqual(harness.environment.reminderModes.count, 0)
        XCTAssertEqual(harness.environment.overlayModes, [.longBreak])
        XCTAssertEqual(harness.environment.commitPresentationCount, 1)
    }

    func testCancelPendingBreakKeepsFocusAnalyticsAndCyclePosition() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.controller.cancelPendingBreak()

        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .focus))
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].mode, .focus)
        XCTAssertEqual(harness.settings.focusCycleCount, 1)
        XCTAssertEqual(harness.environment.cleanupCount, 1)
        XCTAssertFalse(harness.scheduler.isScheduled)
    }

    func testPendingTimeIsNeitherFocusNorBreakTimeAndDeferralIsPreserved() {
        let harness = ControllerHarness()
        harness.completeFocus()
        guard case .breakPending(let pending) = harness.controller.state else {
            return XCTFail("Expected Break Pending")
        }
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 1)
        harness.advance(120)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 60)

        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 1)
        harness.controller.handleTick()
        harness.advance(3)
        harness.advance(57)

        XCTAssertEqual(harness.recorder.records.count, 2)
        let breakRecord = harness.recorder.records[1]
        XCTAssertEqual(breakRecord.mode, .shortBreak)
        XCTAssertEqual(breakRecord.scheduledAt, pending.scheduledAt)
        XCTAssertEqual(breakRecord.startedAt.timeIntervalSince(pending.scheduledAt), 120, accuracy: 0.001)
        XCTAssertEqual(breakRecord.activeDuration, 60)
    }

    func testOverlayFailureUsesCleanupAndReturnsSafeIdleState() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.environment.shouldFailOverlay = true

        harness.controller.startPendingBreakNow()

        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .focus))
        XCTAssertEqual(harness.environment.cleanupCount, 1)
        XCTAssertNotNil(harness.controller.lastError)
        XCTAssertFalse(harness.scheduler.isScheduled)
        XCTAssertEqual(harness.recorder.records.count, 1)
    }

    func testActivityMonitorIsSampledOnlyInPendingAndEnteringStates() {
        let harness = ControllerHarness()
        harness.controller.handleTick()
        XCTAssertEqual(harness.activity.sampleCount, 0)

        harness.startFocus()
        harness.advance(1)
        XCTAssertEqual(harness.activity.sampleCount, 0)

        harness.advance(59)
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 1)
        harness.controller.handleTick()
        XCTAssertEqual(harness.activity.sampleCount, 1)
        harness.controller.cancelPendingBreak()
        harness.controller.handleTick()
        XCTAssertEqual(harness.activity.sampleCount, 1)
    }
}

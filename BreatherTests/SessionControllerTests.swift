import XCTest
@testable import Breather

@MainActor
final class SessionControllerTests: XCTestCase {
    func testIdleCanSelectEveryModeAndShowsItsConfiguredDuration() {
        let harness = ControllerHarness()

        for mode in SessionMode.allCases {
            harness.controller.selectMode(mode)
            XCTAssertEqual(harness.controller.currentMode, mode)
            XCTAssertEqual(harness.controller.remainingTime, 60)
        }
    }

    func testStartingEachModeCreatesOneStableSessionAndOneScheduler() {
        for mode in SessionMode.allCases {
            let harness = ControllerHarness()
            harness.controller.selectMode(mode)
            harness.controller.startSelectedMode()
            guard case .running(let firstSession) = harness.controller.state else {
                return XCTFail("Expected running \(mode)")
            }

            harness.controller.startSelectedMode()
            guard case .running(let repeatedSession) = harness.controller.state else {
                return XCTFail("Expected running \(mode)")
            }
            XCTAssertEqual(firstSession.id, repeatedSession.id)
            XCTAssertEqual(firstSession.mode, mode)
            XCTAssertEqual(harness.scheduler.scheduleCount, 1)
            XCTAssertEqual(harness.environment.overlayModes.count, mode.isBreak ? 1 : 0)
        }
    }

    func testFocusPauseResumeExcludesPausedTimeFromAnalytics() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(10)
        harness.controller.pauseFocus()
        guard case .paused(let paused) = harness.controller.state else {
            return XCTFail("Expected paused Focus")
        }
        XCTAssertEqual(paused.remainingDuration, 50, accuracy: 0.001)
        XCTAssertFalse(harness.scheduler.isScheduled)

        harness.advance(20)
        harness.controller.resumeFocus()
        guard case .running(let resumed) = harness.controller.state else {
            return XCTFail("Expected resumed Focus")
        }
        XCTAssertEqual(resumed.deadline.timeIntervalSince(harness.clock.now), 50, accuracy: 0.001)

        harness.advance(5)
        harness.controller.stopCurrentSession()
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 15, accuracy: 0.001)
        XCTAssertEqual(harness.recorder.records[0].outcome, .stopped)
    }

    func testFocusStopFinalizesExactlyOnceAndReturnsIdle() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(12)
        harness.controller.stopCurrentSession()
        harness.controller.stopCurrentSession()

        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 12, accuracy: 0.001)
        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .focus))
        XCTAssertFalse(harness.scheduler.isScheduled)
    }

    func testBreakCannotPauseOrUseNormalModeSwitching() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.shortBreak)
        harness.controller.startSelectedMode()
        let originalState = harness.controller.state

        harness.controller.pauseFocus()
        harness.controller.requestModeSwitch(to: .longBreak)

        XCTAssertEqual(harness.controller.state, originalState)
        XCTAssertNil(harness.controller.modeSwitchTarget)
    }

    func testRemainingTimeNeverBecomesNegative() {
        let harness = ControllerHarness { settings in
            settings.automaticallyStartBreaks = false
        }
        harness.startFocus()
        harness.advance(600)

        XCTAssertGreaterThanOrEqual(harness.controller.remainingTime, 0)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 60)
    }

    func testChangingSettingsDoesNotMoveActiveDeadline() {
        let harness = ControllerHarness()
        harness.startFocus()
        guard case .running(let running) = harness.controller.state else {
            return XCTFail("Expected running Focus")
        }

        harness.settings.focusMinutes = 2
        guard case .running(let unchanged) = harness.controller.state else {
            return XCTFail("Expected running Focus")
        }
        XCTAssertEqual(unchanged.deadline, running.deadline)
        XCTAssertEqual(unchanged.plannedDuration, 60)
    }

    func testModeSwitchRequiresConfirmationAndCancelPreservesFocus() {
        let harness = ControllerHarness()
        harness.startFocus()
        guard case .running(let original) = harness.controller.state else {
            return XCTFail("Expected running Focus")
        }

        harness.controller.requestModeSwitch(to: .shortBreak)
        XCTAssertEqual(harness.controller.modeSwitchTarget, .shortBreak)
        harness.controller.cancelModeSwitch()

        guard case .running(let current) = harness.controller.state else {
            return XCTFail("Expected Focus to continue")
        }
        XCTAssertEqual(current.id, original.id)
        XCTAssertTrue(harness.recorder.records.isEmpty)
    }

    func testConfirmedModeSwitchFinalizesFocusAndStartsOneBreak() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(8)
        harness.controller.requestModeSwitch(to: .longBreak)
        harness.controller.confirmModeSwitch()
        harness.controller.confirmModeSwitch()

        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .switchedMode)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 8, accuracy: 0.001)
        guard case .running(let running) = harness.controller.state else {
            return XCTFail("Expected Long Break")
        }
        XCTAssertEqual(running.mode, .longBreak)
        XCTAssertEqual(harness.environment.overlayModes, [.longBreak])
        XCTAssertTrue(harness.scheduler.isScheduled)
    }

    func testAbsoluteDeadlineHandlesDelayedTimerCallback() {
        let harness = ControllerHarness { settings in
            settings.automaticallyStartBreaks = false
        }
        harness.startFocus()
        harness.clock.advance(75)
        XCTAssertEqual(harness.controller.remainingTime, 60, "UI snapshot changes only on its lightweight tick")

        harness.controller.handleTick()
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .completed)
        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .shortBreak))
    }

    func testDurationFormatterSupportsHoursAndClampsNegativeValues() {
        XCTAssertEqual(DurationFormatter.timer(3_661), "01:01:01")
        XCTAssertEqual(DurationFormatter.timer(-10), "00:00")
        XCTAssertEqual(DurationFormatter.timer(59.1), "01:00")
    }

    func testSettingsAreClampedToAllowedRanges() {
        let harness = ControllerHarness()
        harness.settings.focusMinutes = 999
        harness.settings.shortBreakMinutes = 0
        harness.settings.longBreakMinutes = 999
        harness.settings.longBreakEvery = 1
        harness.settings.idleBeforeBreak = 8
        harness.settings.breakEntryGracePeriod = 99
        harness.settings.soundVolume = -2

        XCTAssertEqual(harness.settings.focusMinutes, 180)
        XCTAssertEqual(harness.settings.shortBreakMinutes, 1)
        XCTAssertEqual(harness.settings.longBreakMinutes, 120)
        XCTAssertEqual(harness.settings.longBreakEvery, 2)
        XCTAssertEqual(harness.settings.idleBeforeBreak, 10)
        XCTAssertEqual(harness.settings.breakEntryGracePeriod, 10)
        XCTAssertEqual(harness.settings.soundVolume, 0)
    }
}

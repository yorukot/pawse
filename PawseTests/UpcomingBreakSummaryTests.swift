import XCTest
@testable import Breather

@MainActor
final class UpcomingBreakSummaryTests: XCTestCase {
    func testIdleSummaryProjectsTheFullTwoShortBreakCycle() {
        let harness = ControllerHarness { settings in
            settings.focusSeconds = 1_500
            settings.shortBreakSeconds = 30
            settings.longBreakSeconds = 600
            settings.shortBreaksBeforeLongBreak = 2
        }

        let summary = harness.controller.upcomingBreakSummary

        XCTAssertEqual(summary.shortBreak, .estimated(1_500))
        XCTAssertEqual(summary.longBreak, .estimated(4_560))
    }

    func testRunningAndPausedFocusUseActiveRemainingTime() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(10)

        var summary = harness.controller.upcomingBreakSummary
        XCTAssertEqual(summary.shortBreak, .estimated(50))
        XCTAssertEqual(summary.longBreak, .estimated(290))

        harness.controller.pauseFocus()
        harness.advance(30)
        summary = harness.controller.upcomingBreakSummary
        XCTAssertEqual(summary.shortBreak, .estimated(50))
        XCTAssertEqual(summary.longBreak, .estimated(290))
    }

    func testQueuedFocusSegmentsExcludeSkippedBreaksFromProjection() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
        }
        harness.startFocus()
        harness.controller.skipNextBreak()
        harness.controller.skipNextBreak()

        var summary = harness.controller.upcomingBreakSummary
        XCTAssertEqual(summary.longBreak, .estimated(180))
        XCTAssertEqual(summary.shortBreak, .estimated(300))

        harness.advance(60)
        summary = harness.controller.upcomingBreakSummary
        XCTAssertEqual(summary.longBreak, .estimated(120))
        XCTAssertEqual(summary.shortBreak, .estimated(240))
    }

    func testProjectionResetsAfterSkippedLongBreak() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        harness.startFocus()
        harness.controller.skipNextBreak()

        let summary = harness.controller.upcomingBreakSummary

        XCTAssertEqual(summary.shortBreak, .estimated(120))
        XCTAssertEqual(summary.longBreak, .estimated(360))
    }

    func testPendingShortBreakIsReadyAndProjectsTheLongBreakThroughIntermediateSessions() {
        let harness = ControllerHarness()
        harness.completeFocus()

        let summary = harness.controller.upcomingBreakSummary

        XCTAssertEqual(summary.shortBreak, .readyNow)
        XCTAssertEqual(summary.longBreak, .estimated(240))
    }

    func testActiveShortBreakIsInProgress() {
        let harness = ControllerHarness()
        harness.completeFocus()
        harness.commitPendingBreak()

        let summary = harness.controller.upcomingBreakSummary

        XCTAssertEqual(summary.shortBreak, .inProgress)
        XCTAssertEqual(summary.longBreak, .estimated(237))
    }

    func testPendingLongBreakIsReadyAndProjectsShortBreakAfterCycleReset() {
        let harness = ControllerHarness { settings in
            settings.focusCycleCount = 2
        }
        harness.completeFocus()

        let summary = harness.controller.upcomingBreakSummary

        XCTAssertEqual(summary.longBreak, .readyNow)
        XCTAssertEqual(summary.shortBreak, .estimated(120))
    }

    func testDisabledLongBreakSchedulingShowsShortBreakOnly() {
        let harness = ControllerHarness { settings in
            settings.enableLongBreaks = false
        }

        let summary = harness.controller.upcomingBreakSummary

        XCTAssertEqual(summary.shortBreak, .estimated(60))
        XCTAssertEqual(summary.longBreak, .disabled)
    }

    func testDurationEstimateUsesReadableHourFormatting() {
        let english = Locale(identifier: "en_US")
        XCTAssertEqual(DurationFormatter.estimate(0, locale: english), "0 sec")
        XCTAssertEqual(DurationFormatter.estimate(32, locale: english), "32 sec")
        XCTAssertEqual(DurationFormatter.estimate(1_492, locale: english), "24 min, 52 sec")
        XCTAssertEqual(DurationFormatter.estimate(4_560, locale: english), "1 hr, 16 min")
    }
}

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

    func testEveryModeSupportsSecondLevelDurations() {
        let harness = ControllerHarness { settings in
            settings.focusSeconds = 30
            settings.shortBreakSeconds = 40
            settings.longBreakSeconds = 50
        }
        let expectedDurations: [SessionMode: TimeInterval] = [
            .focus: 30,
            .shortBreak: 40,
            .longBreak: 50
        ]

        for mode in SessionMode.allCases {
            harness.controller.selectMode(mode)
            XCTAssertEqual(harness.controller.remainingTime, expectedDurations[mode])
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

    func testLaunchStartsOneAutomaticFocusSession() {
        let harness = ControllerHarness()

        harness.controller.startFocusAtLaunch()
        harness.controller.startFocusAtLaunch()

        guard case .running(let session) = harness.controller.state else {
            return XCTFail("Expected Focus to start at launch")
        }
        XCTAssertEqual(session.mode, .focus)
        XCTAssertEqual(session.origin, .automatic)
        XCTAssertEqual(harness.scheduler.scheduleCount, 1)
        XCTAssertTrue(harness.recorder.records.isEmpty)
    }

    func testBackgroundFocusUsesCoarseRefreshUntilMenuIsPresented() {
        let harness = ControllerHarness { settings in
            settings.focusSeconds = 120
        }
        harness.startFocus()

        XCTAssertEqual(
            harness.scheduler.interval,
            SessionController.backgroundFocusRefreshInterval
        )

        harness.controller.setMenuBarExtraPresented(true)
        XCTAssertEqual(harness.scheduler.interval, 1)

        harness.controller.setMenuBarExtraPresented(false)
        XCTAssertEqual(
            harness.scheduler.interval,
            SessionController.backgroundFocusRefreshInterval
        )
    }

    func testBackgroundFocusReturnsToSecondRefreshNearDeadline() {
        let harness = ControllerHarness { settings in
            settings.focusSeconds = 120
        }
        harness.startFocus()

        harness.advance(91)

        XCTAssertEqual(harness.scheduler.interval, 1)
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
        harness.controller.switchMode(to: .longBreak)

        XCTAssertEqual(harness.controller.state, originalState)
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

        harness.settings.focusSeconds = 120
        guard case .running(let unchanged) = harness.controller.state else {
            return XCTFail("Expected running Focus")
        }
        XCTAssertEqual(unchanged.deadline, running.deadline)
        XCTAssertEqual(unchanged.plannedDuration, 60)
    }

    func testSkippingBreaksAddsConfiguredFocusDurationsWhileRunningAndPaused() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(10)

        harness.controller.skipNextBreak()
        XCTAssertEqual(harness.controller.remainingTime, 110, accuracy: 0.001)
        XCTAssertEqual(harness.controller.progress, 10.0 / 120.0, accuracy: 0.001)

        harness.controller.pauseFocus()
        harness.controller.skipNextBreak()
        XCTAssertEqual(harness.controller.remainingTime, 170, accuracy: 0.001)
        XCTAssertEqual(harness.controller.progress, 10.0 / 180.0, accuracy: 0.001)

        harness.controller.resumeFocus()
        XCTAssertEqual(harness.controller.remainingTime, 170, accuracy: 0.001)
        XCTAssertEqual(harness.controller.countdownFractionRemaining ?? -1, 170.0 / 180.0, accuracy: 0.001)
    }

    func testSkipCurrentFocusClearsQueuedFocusesAndImmediatelyStartsBreak() {
        let harness = ControllerHarness { settings in
            settings.automaticallyStartBreaks = false
            settings.waitForNaturalBreak = true
        }
        harness.startFocus()
        harness.advance(12)
        harness.controller.skipNextBreak()
        harness.controller.skipNextBreak()

        harness.controller.skipCurrentFocus()
        harness.controller.skipCurrentFocus()

        XCTAssertEqual(harness.settings.focusCycleCount, 1)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .skipped)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 12, accuracy: 0.001)
        guard case .running(let runningBreak) = harness.controller.state else {
            return XCTFail("Expected an immediate Break")
        }
        XCTAssertEqual(runningBreak.mode, .shortBreak)
        XCTAssertEqual(runningBreak.origin, .automatic)
        XCTAssertEqual(runningBreak.scheduledAt, harness.clock.now)
        XCTAssertEqual(runningBreak.cyclePosition, 1)
        XCTAssertEqual(harness.environment.overlayModes, [.shortBreak])
        XCTAssertEqual(harness.environment.commitPresentationCount, 1)
        XCTAssertEqual(
            harness.sound.events,
            [.sessionStarted(.focus), .sessionStarted(.shortBreak)]
        )
        XCTAssertTrue(harness.scheduler.isScheduled)

        harness.advance(60)
        harness.startFocus()
        XCTAssertEqual(harness.controller.remainingTime, 60, accuracy: 0.001)
    }

    func testSkipPausedFocusPreservesActiveTimeAndStartsLongBreak() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
            settings.automaticallyStartBreaks = false
        }
        harness.startFocus()
        harness.advance(9)
        harness.controller.pauseFocus()

        harness.controller.skipCurrentFocus()

        XCTAssertEqual(harness.settings.focusCycleCount, 3)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .skipped)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 9, accuracy: 0.001)
        guard case .running(let runningBreak) = harness.controller.state else {
            return XCTFail("Expected an immediate Long Break")
        }
        XCTAssertEqual(runningBreak.mode, .longBreak)
        XCTAssertEqual(runningBreak.cyclePosition, 3)
        XCTAssertEqual(harness.environment.overlayModes, [.longBreak])
        XCTAssertTrue(harness.scheduler.isScheduled)
    }

    func testEachQueuedFocusIsRecordedAndTwoSkippedBreaksLeadToLongBreak() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
        }
        let startedAt = harness.clock.now
        harness.startFocus()
        harness.controller.skipNextBreak()
        harness.controller.skipNextBreak()

        harness.advance(190)

        guard case .breakPending(let pending) = harness.controller.state else {
            return XCTFail("Expected Long Break after three completed Focus segments")
        }
        XCTAssertEqual(pending.mode, .longBreak)
        XCTAssertEqual(harness.settings.focusCycleCount, 3)
        XCTAssertEqual(harness.recorder.records.count, 3)
        XCTAssertEqual(harness.recorder.records.map(\.mode), [.focus, .focus, .focus])
        XCTAssertTrue(harness.recorder.records.allSatisfy { $0.outcome == .completed })
        XCTAssertTrue(harness.recorder.records.allSatisfy { $0.plannedDuration == 60 })
        XCTAssertTrue(harness.recorder.records.allSatisfy { $0.activeDuration == 60 })
        XCTAssertEqual(harness.recorder.records[0].startedAt, startedAt)
        XCTAssertEqual(harness.recorder.records[0].endedAt, startedAt.addingTimeInterval(60))
        XCTAssertEqual(harness.recorder.records[1].startedAt, startedAt.addingTimeInterval(60))
        XCTAssertEqual(harness.recorder.records[1].endedAt, startedAt.addingTimeInterval(120))
        XCTAssertEqual(harness.recorder.records[2].startedAt, startedAt.addingTimeInterval(120))
        XCTAssertEqual(harness.recorder.records[2].endedAt, startedAt.addingTimeInterval(180))
        XCTAssertEqual(harness.sound.events, [.sessionStarted(.focus), .breakReady(.longBreak)])
        XCTAssertEqual(harness.environment.reminderModes, [.longBreak])
        XCTAssertTrue(harness.environment.overlayModes.isEmpty)
    }

    func testSkippingScheduledLongBreakResetsCycleBeforeQueuedFocus() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        harness.startFocus()
        harness.controller.skipNextBreak()

        harness.advance(120)

        guard case .breakPending(let pending) = harness.controller.state else {
            return XCTFail("Expected Short Break after the skipped Long Break")
        }
        XCTAssertEqual(pending.mode, .shortBreak)
        XCTAssertEqual(pending.cyclePosition, 1)
        XCTAssertEqual(harness.settings.focusCycleCount, 1)
        XCTAssertEqual(harness.recorder.records.count, 2)
    }

    func testSkippingBreakHidesReminderUntilFinalQueuedFocusDeadline() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(50)
        XCTAssertEqual(harness.environment.reminderModes, [.shortBreak])

        harness.controller.skipNextBreak()
        XCTAssertEqual(harness.controller.remainingTime, 70, accuracy: 0.001)
        XCTAssertEqual(harness.environment.hideReminderCount, 1)

        harness.controller.startBreakFromReminder()
        guard case .running(let extendedFocus) = harness.controller.state else {
            return XCTFail("The stale reminder must not start a queued break")
        }
        XCTAssertEqual(extendedFocus.mode, .focus)
        XCTAssertTrue(harness.recorder.records.isEmpty)

        harness.advance(10)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.environment.reminderModes, [.shortBreak])

        harness.advance(50)
        XCTAssertEqual(harness.environment.reminderModes, [.shortBreak, .shortBreak])
    }

    func testQueuedDurationIsCapturedAndFutureSkipsUseLatestSetting() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.controller.skipNextBreak()
        XCTAssertEqual(harness.controller.remainingTime, 120, accuracy: 0.001)

        harness.settings.focusSeconds = 120
        XCTAssertEqual(harness.controller.remainingTime, 120, accuracy: 0.001)

        harness.controller.skipNextBreak()
        XCTAssertEqual(harness.controller.remainingTime, 240, accuracy: 0.001)
    }

    func testStoppingFocusDiscardsQueuedSegmentsWithoutAdvancingCycle() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.controller.skipNextBreak()
        harness.advance(10)
        harness.controller.stopCurrentSession()

        XCTAssertEqual(harness.settings.focusCycleCount, 0)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .stopped)

        harness.startFocus()
        XCTAssertEqual(harness.controller.remainingTime, 60, accuracy: 0.001)
    }

    func testCountdownFractionTracksAbsoluteRemainingTime() {
        let harness = ControllerHarness()
        harness.startFocus()
        XCTAssertEqual(harness.controller.countdownFractionRemaining ?? -1, 1, accuracy: 0.001)

        harness.advance(15)
        XCTAssertEqual(harness.controller.countdownFractionRemaining ?? -1, 0.75, accuracy: 0.001)

        harness.controller.pauseFocus()
        XCTAssertEqual(harness.controller.countdownFractionRemaining ?? -1, 0.75, accuracy: 0.001)
    }

    func testSwitchModeFinalizesFocusAndStartsOneBreak() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(8)
        harness.controller.switchMode(to: .longBreak)
        harness.controller.switchMode(to: .longBreak)

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
        let english = Locale(identifier: "en_US")
        XCTAssertEqual(DurationFormatter.timer(3_661), "01:01:01")
        XCTAssertEqual(DurationFormatter.timer(-10), "00:00")
        XCTAssertEqual(DurationFormatter.timer(59.1), "01:00")
        XCTAssertEqual(DurationFormatter.concise(30, locale: english), "30 sec")
        XCTAssertEqual(DurationFormatter.concise(60, locale: english), "1 min")
        XCTAssertEqual(DurationFormatter.concise(90, locale: english), "1 min, 30 sec")
    }

    func testSettingsAreClampedToAllowedRanges() {
        let harness = ControllerHarness()
        harness.settings.focusSeconds = 99_999
        harness.settings.shortBreakSeconds = 0
        harness.settings.longBreakSeconds = 99_999
        harness.settings.shortBreaksBeforeLongBreak = 0
        harness.settings.idleBeforeBreak = 8
        harness.settings.breakEntryGracePeriod = 99
        harness.settings.soundVolume = -2

        XCTAssertEqual(harness.settings.focusSeconds, 10_800)
        XCTAssertEqual(harness.settings.shortBreakSeconds, 10)
        XCTAssertEqual(harness.settings.longBreakSeconds, 7_200)
        XCTAssertEqual(harness.settings.shortBreaksBeforeLongBreak, 1)
        XCTAssertEqual(harness.settings.idleBeforeBreak, 10)
        XCTAssertEqual(harness.settings.breakEntryGracePeriod, 10)
        XCTAssertEqual(harness.settings.soundVolume, 0)

        harness.settings.focusSeconds = 1_505
        XCTAssertEqual(harness.settings.focusSeconds, 1_510)
    }

    func testProductDefaultsMatchAutomaticTwentyFiveMinuteCycle() {
        let suiteName = "PawseDefaultsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated defaults")
        }
        defaults.removePersistentDomain(forName: suiteName)
        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.focusSeconds, 1_500)
        XCTAssertEqual(settings.shortBreakSeconds, 30)
        XCTAssertEqual(settings.longBreakSeconds, 600)
        XCTAssertEqual(settings.shortBreaksBeforeLongBreak, 2)
        XCTAssertTrue(settings.automaticallyStartBreaks)
        XCTAssertTrue(settings.automaticallyStartNextFocus)
        XCTAssertTrue(settings.continueCycleAfterEmergencyExit)
    }
}

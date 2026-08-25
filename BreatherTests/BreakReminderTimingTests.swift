import XCTest
@testable import Breather

@MainActor
final class BreakReminderTimingTests: XCTestCase {
    func testReminderAppearsOnceWhenFocusEntersItsFinalTenSeconds() {
        let harness = ControllerHarness()
        harness.startFocus()

        harness.advance(49)
        XCTAssertTrue(harness.environment.reminderPresentations.isEmpty)

        harness.advance(1)
        XCTAssertEqual(harness.environment.reminderPresentations.count, 1)
        XCTAssertEqual(harness.environment.reminderModes, [.shortBreak])
        XCTAssertEqual(harness.activity.sampleCount, 0)

        guard case .upcoming(let deadline, let leadTime) =
            harness.environment.reminderPresentations[0].phase,
            case .running(let session) = harness.controller.state else {
            return XCTFail("Expected an upcoming reminder for the running Focus")
        }
        XCTAssertEqual(deadline, session.deadline)
        XCTAssertEqual(leadTime, 10)

        harness.controller.handleTick()
        XCTAssertEqual(harness.environment.reminderPresentations.count, 1)
        XCTAssertEqual(harness.activity.sampleCount, 0)
    }

    func testReminderUsesTheBreakModeScheduledForTheCompletedFocus() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        harness.startFocus()

        harness.advance(50)

        XCTAssertEqual(harness.environment.reminderModes, [.longBreak])
    }

    func testClickingUpcomingReminderCompletesFocusAtActualDurationAndBeginsEntryOnce() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(52)

        harness.controller.startBreakFromReminder()
        harness.controller.startBreakFromReminder()

        guard case .breakEntering(let entry) = harness.controller.state else {
            return XCTFail("Expected the selected break to begin entering")
        }
        XCTAssertEqual(entry.mode, .shortBreak)
        XCTAssertEqual(entry.scheduledAt, harness.clock.now)
        XCTAssertEqual(harness.settings.focusCycleCount, 1)
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .completed)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 52, accuracy: 0.001)
        XCTAssertEqual(harness.environment.overlayModes, [.shortBreak])
        XCTAssertEqual(harness.sound.events.filter { $0 == .breakReady(.shortBreak) }.count, 1)
        XCTAssertEqual(harness.environment.reminderPresentations.count, 1)
    }

    func testNaturalFocusCompletionUpdatesUpcomingReminderToReady() {
        let harness = ControllerHarness()
        harness.startFocus()

        harness.advance(50)
        harness.advance(10)

        guard case .breakPending(let pending) = harness.controller.state else {
            return XCTFail("Expected Break Pending")
        }
        XCTAssertEqual(harness.environment.reminderPresentations.count, 2)
        XCTAssertEqual(
            harness.environment.reminderPresentations.last,
            BreakReminderPresentation(
                mode: .shortBreak,
                phase: .ready(scheduledAt: pending.scheduledAt)
            )
        )
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 60)
        XCTAssertEqual(harness.sound.events.filter { $0 == .breakReady(.shortBreak) }.count, 1)
    }

    func testReminderIsHiddenWhilePausedAndReappearsForTheResumedDeadline() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(50)

        harness.controller.pauseFocus()
        XCTAssertEqual(harness.environment.hideReminderCount, 1)

        harness.advance(20)
        harness.controller.resumeFocus()

        XCTAssertEqual(harness.environment.reminderPresentations.count, 2)
        guard case .upcoming(let resumedDeadline, _) =
            harness.environment.reminderPresentations.last?.phase else {
            return XCTFail("Expected the upcoming reminder to return on resume")
        }
        XCTAssertEqual(resumedDeadline.timeIntervalSince(harness.clock.now), 10, accuracy: 0.001)
    }

    func testAutomaticBreaksDisabledNeverShowsUpcomingReminder() {
        let harness = ControllerHarness { settings in
            settings.automaticallyStartBreaks = false
        }
        harness.startFocus()

        harness.advance(50)
        XCTAssertTrue(harness.environment.reminderPresentations.isEmpty)

        harness.advance(10)
        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .shortBreak))
        XCTAssertTrue(harness.environment.reminderPresentations.isEmpty)
    }

    func testUpcomingReminderAlsoPrecedesAnImmediateAutomaticBreak() {
        let harness = ControllerHarness { settings in
            settings.waitForNaturalBreak = false
        }
        harness.startFocus()
        harness.advance(50)

        XCTAssertEqual(harness.environment.reminderModes, [.shortBreak])

        harness.controller.startBreakFromReminder()

        guard case .running(let session) = harness.controller.state else {
            return XCTFail("Expected the immediate break to be active")
        }
        XCTAssertEqual(session.mode, .shortBreak)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 50, accuracy: 0.001)
        XCTAssertEqual(harness.environment.overlayModes, [.shortBreak])
        XCTAssertEqual(harness.environment.commitPresentationCount, 1)
    }
}

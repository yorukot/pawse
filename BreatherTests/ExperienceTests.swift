import AppKit
import XCTest
@testable import Breather

@MainActor
final class ExperienceTests: XCTestCase {
    func testNewDefaultsMatchAutomaticCycleExperience() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.focusMinutes, 25)
        XCTAssertEqual(settings.shortBreakSeconds, 30)
        XCTAssertEqual(settings.longBreakMinutes, 10)
        XCTAssertEqual(settings.shortBreaksBeforeLongBreak, 2)
        XCTAssertEqual(settings.idleBeforeBreak, 3)
        XCTAssertTrue(settings.automaticallyStartBreaks)
        XCTAssertTrue(settings.automaticallyStartNextFocus)
        XCTAssertEqual(settings.breakBackgroundMode, .systemWallpaper)
    }

    func testCustomBackgroundSelectionPersistsAndSettingsResetClearsIt() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = SettingsStore(defaults: defaults)
        settings.setCustomBreakImage(bookmark: Data([1, 2, 3]), fileName: "Rest.jpg")

        settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.breakBackgroundMode, .customImage)
        XCTAssertEqual(settings.customBreakImageName, "Rest.jpg")
        XCTAssertEqual(settings.customBreakImageBookmark, Data([1, 2, 3]))

        settings.resetToDefaults()
        XCTAssertEqual(settings.breakBackgroundMode, .systemWallpaper)
        XCTAssertNil(settings.customBreakImageName)
        XCTAssertNil(settings.customBreakImageBookmark)
    }

    func testUpcomingBreakSummaryExplainsTwoShortBreakCycle() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.shortBreakSeconds = 30
            settings.longBreakMinutes = 10
        }

        var summary = harness.controller.upcomingBreakSummary
        XCTAssertEqual(summary.nextMode, .shortBreak)
        XCTAssertEqual(summary.nextDuration, 30)
        XCTAssertEqual(summary.focusSessionsUntilLongBreak, 3)
        XCTAssertEqual(summary.longBreakDuration, 600)

        harness.settings.focusCycleCount = 2
        summary = harness.controller.upcomingBreakSummary
        XCTAssertEqual(summary.nextMode, .longBreak)
        XCTAssertEqual(summary.focusSessionsUntilLongBreak, 1)

        harness.settings.focusCycleCount = 3
        summary = harness.controller.upcomingBreakSummary
        XCTAssertEqual(summary.nextMode, .longBreak)
        XCTAssertEqual(summary.focusSessionsUntilLongBreak, 0)
    }

    func testBreakReminderAttentionProgressBecomesUrgentWithoutForcingTransition() {
        let scheduledAt = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            BreakReminderView.attentionProgress(scheduledAt: scheduledAt, now: scheduledAt),
            0
        )
        XCTAssertEqual(
            BreakReminderView.attentionProgress(
                scheduledAt: scheduledAt,
                now: scheduledAt.addingTimeInterval(7.5)
            ),
            0.5,
            accuracy: 0.001
        )
        XCTAssertFalse(
            BreakReminderView.isUrgent(
                scheduledAt: scheduledAt,
                now: scheduledAt.addingTimeInterval(14.9)
            )
        )
        XCTAssertTrue(
            BreakReminderView.isUrgent(
                scheduledAt: scheduledAt,
                now: scheduledAt.addingTimeInterval(15)
            )
        )
        XCTAssertEqual(
            BreakReminderView.attentionProgress(
                scheduledAt: scheduledAt,
                now: scheduledAt.addingTimeInterval(120)
            ),
            1
        )
    }

    func testDeferredEntryRetryKeepsOriginalReminderTimeline() {
        let harness = ControllerHarness()
        harness.completeFocus()
        guard case .breakPending(let firstPending) = harness.controller.state else {
            return XCTFail("Expected pending break")
        }

        harness.controller.startPendingBreakNow()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 1)
        harness.advance(1)

        guard case .breakPending(let retriedPending) = harness.controller.state else {
            return XCTFail("Expected entry activity to return to pending")
        }
        XCTAssertEqual(retriedPending.scheduledAt, firstPending.scheduledAt)
        XCTAssertEqual(harness.environment.pendingReminders.count, 2)
        XCTAssertEqual(harness.environment.pendingReminders.last?.scheduledAt, firstPending.scheduledAt)
        XCTAssertEqual(harness.environment.cleanupAnimationValues.last, true)
    }

    func testEmergencyExitUsesImmediateSafetyCleanup() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.shortBreak)
        harness.controller.startSelectedMode()
        harness.controller.requestEmergencyExit()
        harness.controller.confirmEmergencyExit()

        XCTAssertEqual(harness.environment.cleanupAnimationValues.last, false)
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "BreatherExperienceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

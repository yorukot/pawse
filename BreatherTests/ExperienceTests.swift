import AppKit
import XCTest
@testable import Breather

@MainActor
final class ExperienceTests: XCTestCase {
    func testBrandImagesAreAvailableInApplicationBundle() {
        XCTAssertNotNil(NSImage(named: "BreatherLogo"))
        XCTAssertNotNil(NSImage(named: "BreatherBanner"))
        let menuBarCat = NSImage(named: "MenuBarSleepingCat")
        XCTAssertNotNil(menuBarCat)
        XCTAssertTrue(menuBarCat?.isTemplate == true)
        XCTAssertNotNil(NSImage(named: NSImage.applicationIconName))
    }

    func testNewDefaultsMatchAutomaticCycleExperience() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.focusSeconds, 1_500)
        XCTAssertEqual(settings.shortBreakSeconds, 30)
        XCTAssertEqual(settings.longBreakSeconds, 600)
        XCTAssertEqual(settings.shortBreaksBeforeLongBreak, 2)
        XCTAssertEqual(settings.idleBeforeBreak, 2)
        XCTAssertTrue(settings.automaticallyStartBreaks)
        XCTAssertTrue(settings.automaticallyStartNextFocus)
        XCTAssertEqual(settings.menuBarIconStyle, .sleepingCat)
        XCTAssertEqual(settings.breakBackgroundMode, .systemWallpaper)
        XCTAssertNil(settings.customBreakImageBookmark)
        XCTAssertNil(settings.systemWallpaperFolderBookmark)
    }

    func testLegacyMinuteDurationsMigrateToSeconds() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(25, forKey: SettingsStore.Key.legacyFocusMinutes)
        defaults.set(10, forKey: SettingsStore.Key.legacyLongBreakMinutes)

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.focusSeconds, 1_500)
        XCTAssertEqual(settings.longBreakSeconds, 600)
        XCTAssertEqual(defaults.integer(forKey: SettingsStore.Key.focusSeconds), 1_500)
        XCTAssertEqual(defaults.integer(forKey: SettingsStore.Key.longBreakSeconds), 600)
    }

    func testStoredSecondDurationsTakePriorityOverLegacyMinutes() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(25, forKey: SettingsStore.Key.legacyFocusMinutes)
        defaults.set(300, forKey: SettingsStore.Key.focusSeconds)

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.focusSeconds, 300)
    }

    func testMenuBarIconStylePersistsFallsBackAndResets() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = SettingsStore(defaults: defaults)
        settings.menuBarIconStyle = .timer

        settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.menuBarIconStyle, .timer)

        defaults.set("unsupported", forKey: SettingsStore.Key.menuBarIconStyle)
        settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.menuBarIconStyle, .sleepingCat)

        settings.menuBarIconStyle = .timer
        settings.resetToDefaults()
        XCTAssertEqual(settings.menuBarIconStyle, .sleepingCat)
    }

    func testCustomBackgroundSelectionPersistsAndSettingsResetClearsIt() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = SettingsStore(defaults: defaults)
        settings.setCustomBreakImage(bookmark: Data([1, 2, 3]), fileName: "Rest.jpg")
        settings.setSystemWallpaperFolder(bookmark: Data([4, 5, 6]), folderName: "Wallpapers")

        settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.breakBackgroundMode, .customImage)
        XCTAssertEqual(settings.customBreakImageName, "Rest.jpg")
        XCTAssertEqual(settings.customBreakImageBookmark, Data([1, 2, 3]))
        XCTAssertEqual(settings.systemWallpaperFolderName, "Wallpapers")
        XCTAssertEqual(settings.systemWallpaperFolderBookmark, Data([4, 5, 6]))

        settings.resetToDefaults()
        XCTAssertEqual(settings.breakBackgroundMode, .systemWallpaper)
        XCTAssertNil(settings.customBreakImageName)
        XCTAssertNil(settings.customBreakImageBookmark)
        XCTAssertNil(settings.systemWallpaperFolderName)
        XCTAssertNil(settings.systemWallpaperFolderBookmark)
    }

    func testSolidColorPreservesSavedBackgroundAccessUntilExplicitReset() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = SettingsStore(defaults: defaults)
        settings.setCustomBreakImage(bookmark: Data([1, 2, 3]), fileName: "Rest.jpg")
        settings.setSystemWallpaperFolder(bookmark: Data([4, 5, 6]), folderName: "Wallpapers")
        settings.breakBackgroundMode = .solidColor

        XCTAssertEqual(settings.breakBackgroundMode, .solidColor)
        XCTAssertEqual(settings.customBreakImageBookmark, Data([1, 2, 3]))
        XCTAssertEqual(settings.systemWallpaperFolderBookmark, Data([4, 5, 6]))

        settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.breakBackgroundMode, .solidColor)
        XCTAssertEqual(settings.customBreakImageName, "Rest.jpg")
        XCTAssertEqual(settings.systemWallpaperFolderName, "Wallpapers")

        settings.clearCustomBreakImage()
        XCTAssertEqual(settings.breakBackgroundMode, .solidColor)
        XCTAssertNil(settings.customBreakImageBookmark)
    }

    func testUpcomingBreakSummaryExplainsTwoShortBreakCycle() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.shortBreakSeconds = 30
            settings.longBreakSeconds = 600
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

    func testBreakReminderAttentionProgressBecomesReadyWithoutForcingTransition() {
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
            BreakReminderView.isAttentionState(
                scheduledAt: scheduledAt,
                now: scheduledAt.addingTimeInterval(14.9)
            )
        )
        XCTAssertTrue(
            BreakReminderView.isAttentionState(
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

    func testBreakReminderCopyUsesSentenceCaseAndNamesLongBreak() {
        XCTAssertEqual(
            BreakReminderView.title(for: .shortBreak, isAttentionState: false),
            "Break soon"
        )
        XCTAssertEqual(
            BreakReminderView.title(for: .shortBreak, isAttentionState: true),
            "Break ready"
        )
        XCTAssertEqual(
            BreakReminderView.title(for: .longBreak, isAttentionState: false),
            "Long break soon"
        )
        XCTAssertEqual(
            BreakReminderView.title(for: .longBreak, isAttentionState: true),
            "Long break ready"
        )
        XCTAssertEqual(
            BreakReminderView.accessibilityLabel(for: .shortBreak, isAttentionState: true),
            "Short break ready. Click to start."
        )
        XCTAssertEqual(
            BreakReminderView.accessibilityLabel(for: .longBreak, isAttentionState: false),
            "Long break soon. Click to start."
        )
    }

    func testBreakReminderPulseAndReduceMotionBehavior() {
        let pulse = BreakReminderView.attentionPulse(
            at: Date(timeIntervalSinceReferenceDate: 0.6),
            isAttentionState: true
        )

        XCTAssertEqual(
            BreakReminderView.attentionPulse(at: .now, isAttentionState: false),
            0
        )
        XCTAssertGreaterThanOrEqual(pulse, 0)
        XCTAssertLessThanOrEqual(pulse, 1)
        XCTAssertGreaterThan(
            BreakReminderView.logoScale(
                pulse: 1,
                isAttentionState: true,
                reduceMotion: false
            ),
            1
        )
        XCTAssertEqual(
            BreakReminderView.logoScale(
                pulse: 1,
                isAttentionState: true,
                reduceMotion: true
            ),
            1
        )
        XCTAssertEqual(
            BreakReminderView.logoScale(
                pulse: 1,
                isAttentionState: false,
                reduceMotion: false
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

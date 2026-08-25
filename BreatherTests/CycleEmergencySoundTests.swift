import XCTest
@testable import Breather

@MainActor
final class CycleEmergencySoundTests: XCTestCase {
    func testInterruptedFocusDoesNotAdvanceCycle() {
        let harness = ControllerHarness()
        harness.startFocus()
        harness.advance(10)
        harness.controller.stopCurrentSession()
        XCTAssertEqual(harness.settings.focusCycleCount, 0)

        harness.startFocus()
        harness.controller.switchMode(to: .shortBreak)
        XCTAssertEqual(harness.settings.focusCycleCount, 0)
    }

    func testTwoShortBreaksAreScheduledBeforeLongBreak() {
        let first = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
        }
        first.completeFocus()
        guard case .breakPending(let shortPending) = first.controller.state else {
            return XCTFail("Expected pending break")
        }
        XCTAssertEqual(shortPending.mode, .shortBreak)

        let second = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        second.completeFocus()
        guard case .breakPending(let longPending) = second.controller.state else {
            return XCTFail("Expected pending break")
        }
        XCTAssertEqual(longPending.mode, .longBreak)
        XCTAssertEqual(longPending.cyclePosition, 3)
    }

    func testCustomShortBreakCountChangesLongBreakSchedule() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 4
            settings.focusCycleCount = 4
        }

        harness.completeFocus()

        guard case .breakPending(let pending) = harness.controller.state else {
            return XCTFail("Expected pending Long Break")
        }
        XCTAssertEqual(pending.mode, .longBreak)
        XCTAssertEqual(pending.cyclePosition, 5)
    }

    func testAutomaticCycleRunsTwoShortBreaksThenLongBreak() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.waitForNaturalBreak = false
            settings.automaticallyStartNextFocus = true
        }

        harness.completeFocus()
        XCTAssertEqual(harness.controller.currentMode, .shortBreak)
        harness.advance(60)
        harness.advance(60)
        XCTAssertEqual(harness.controller.currentMode, .shortBreak)
        harness.advance(60)
        harness.advance(60)

        guard case .running(let longBreak) = harness.controller.state else {
            return XCTFail("Expected Long Break after two Short Breaks")
        }
        XCTAssertEqual(longBreak.mode, .longBreak)
        XCTAssertEqual(harness.recorder.records.map(\.mode), [.focus, .shortBreak, .focus, .shortBreak, .focus])
    }

    func testCompletedScheduledLongBreakResetsCycle() {
        let harness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        harness.completeFocus()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 1)
        harness.controller.handleTick()
        harness.advance(3)
        harness.advance(57)

        XCTAssertEqual(harness.settings.focusCycleCount, 0)
        XCTAssertEqual(harness.recorder.records.map(\.mode), [.focus, .longBreak])
        XCTAssertEqual(harness.recorder.records.last?.outcome, .completed)
    }

    func testEmergencyExitAndPendingCancellationDoNotResetLongBreakCycle() {
        let pendingHarness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        pendingHarness.completeFocus()
        pendingHarness.controller.cancelPendingBreak()
        XCTAssertEqual(pendingHarness.settings.focusCycleCount, 3)

        let activeHarness = ControllerHarness { settings in
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        activeHarness.completeFocus()
        activeHarness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 1)
        activeHarness.controller.handleTick()
        activeHarness.advance(3)
        activeHarness.controller.requestEmergencyExit()
        activeHarness.controller.confirmEmergencyExit()
        XCTAssertEqual(activeHarness.settings.focusCycleCount, 3)
        XCTAssertEqual(activeHarness.recorder.records.last?.outcome, .emergencyExit)
    }

    func testManualBreaksNeverAffectCycle() {
        for mode in [SessionMode.shortBreak, .longBreak] {
            let harness = ControllerHarness { settings in
                settings.focusCycleCount = 1
            }
            harness.controller.selectMode(mode)
            harness.controller.startSelectedMode()
            harness.advance(60)
            XCTAssertEqual(harness.settings.focusCycleCount, 1)
        }
    }

    func testAutomaticBreakDisabledReturnsIdleWithScheduledModeSelected() {
        let harness = ControllerHarness { settings in
            settings.automaticallyStartBreaks = false
            settings.shortBreaksBeforeLongBreak = 2
            settings.focusCycleCount = 2
        }
        harness.completeFocus()

        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .longBreak))
        XCTAssertTrue(harness.environment.reminderModes.isEmpty)
        XCTAssertEqual(harness.recorder.records.count, 1)
    }

    func testAutomaticNextFocusStartsAfterCompletedBreak() {
        let harness = ControllerHarness { settings in
            settings.automaticallyStartNextFocus = true
        }
        harness.controller.selectMode(.shortBreak)
        harness.controller.startSelectedMode()
        harness.advance(60)

        guard case .running(let running) = harness.controller.state else {
            return XCTFail("Expected automatic Focus")
        }
        XCTAssertEqual(running.mode, .focus)
        XCTAssertEqual(running.origin, .automatic)
        XCTAssertEqual(harness.recorder.records.count, 1)
    }

    func testEmergencyExitRequiresConfirmationAndCancelKeepsBreakActive() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.shortBreak)
        harness.controller.startSelectedMode()
        guard case .running(let original) = harness.controller.state else {
            return XCTFail("Expected break")
        }

        harness.controller.requestEmergencyExit()
        XCTAssertTrue(harness.controller.isEmergencyExitConfirmationPresented)
        harness.controller.cancelEmergencyExit()
        XCTAssertFalse(harness.controller.isEmergencyExitConfirmationPresented)
        guard case .running(let current) = harness.controller.state else {
            return XCTFail("Break should continue")
        }
        XCTAssertEqual(current.id, original.id)
        XCTAssertTrue(harness.recorder.records.isEmpty)
    }

    func testConfirmedEmergencyExitCleansUpRecordsAndNeverAutoStarts() {
        let harness = ControllerHarness { settings in
            settings.automaticallyStartNextFocus = true
        }
        harness.controller.selectMode(.longBreak)
        harness.controller.startSelectedMode()
        harness.advance(10)
        harness.controller.requestEmergencyExit()
        harness.controller.confirmEmergencyExit()
        harness.controller.confirmEmergencyExit()

        XCTAssertEqual(harness.controller.state, .idle(selectedMode: .focus))
        XCTAssertEqual(harness.recorder.records.count, 1)
        XCTAssertEqual(harness.recorder.records[0].outcome, .emergencyExit)
        XCTAssertEqual(harness.recorder.records[0].activeDuration, 10, accuracy: 0.001)
        XCTAssertEqual(harness.environment.cleanupCount, 1)
        XCTAssertGreaterThanOrEqual(harness.sound.stopCount, 1)
        XCTAssertFalse(harness.scheduler.isScheduled)
    }

    func testSoundsDisabledSuppressesPlaybackRequests() {
        let harness = ControllerHarness { settings in
            settings.enableSounds = false
        }
        harness.completeFocus()
        XCTAssertTrue(harness.sound.events.isEmpty)
    }

    func testSoundTransitionEventsAreNotDuplicated() {
        let harness = ControllerHarness()
        harness.completeFocus()
        XCTAssertEqual(harness.sound.events, [.sessionStarted(.focus), .breakReady(.shortBreak)])

        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 1)
        harness.controller.handleTick()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 0, activityToken: 2)
        harness.controller.handleTick()
        harness.activity.current = UserActivitySample(secondsSinceLastInput: 5, activityToken: 2)
        harness.controller.handleTick()
        harness.advance(3)

        XCTAssertEqual(harness.sound.events.filter { $0 == .breakReady(.shortBreak) }.count, 1)
        XCTAssertEqual(harness.sound.events.filter { $0 == .breakStarted(.shortBreak) }.count, 1)
    }

    func testEmergencyExitDoesNotPlayNormalCompletionSound() {
        let harness = ControllerHarness()
        harness.controller.selectMode(.shortBreak)
        harness.controller.startSelectedMode()
        harness.controller.requestEmergencyExit()
        harness.controller.confirmEmergencyExit()

        XCTAssertFalse(harness.sound.events.contains(.breakCompleted(.shortBreak)))
    }

    func testSoundPreviewDoesNotChangeSessionOrAnalyticsAndUsesVolume() {
        let harness = ControllerHarness()
        let service = SoundService(settings: harness.settings)
        harness.settings.soundVolume = 0.42
        let beforeState = harness.controller.state

        if let sound = service.availableSounds.first(where: { !$0.isNone }) {
            service.preview(sound)
            XCTAssertEqual(service.lastPlayedName, sound.name)
            XCTAssertEqual(service.lastPlaybackVolume ?? -1, 0.42, accuracy: 0.02)
        } else {
            service.preview(.none)
            XCTAssertNil(service.lastPlayedName)
        }
        XCTAssertEqual(harness.controller.state, beforeState)
        XCTAssertTrue(harness.recorder.records.isEmpty)
    }
}

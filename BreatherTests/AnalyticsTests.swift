import SwiftData
import XCTest
@testable import Breather

@MainActor
final class AnalyticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600) ?? .current
        return calendar
    }

    func testFocusedTimeCompletionRateAndInterruptedMetrics() {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let records = [
            makeSnapshot(mode: .focus, outcome: .completed, startedAt: now.addingTimeInterval(-300), activeDuration: 120),
            makeSnapshot(mode: .focus, outcome: .stopped, startedAt: now.addingTimeInterval(-200), activeDuration: 30),
            makeSnapshot(mode: .focus, outcome: .switchedMode, startedAt: now.addingTimeInterval(-100), activeDuration: 15)
        ]

        let metrics = AnalyticsAggregator.metrics(records: records, range: .allTime, now: now, calendar: calendar)

        XCTAssertEqual(metrics.focusedTime, 165)
        XCTAssertEqual(metrics.completedFocusSessions, 1)
        XCTAssertEqual(metrics.startedFocusSessions, 3)
        XCTAssertEqual(metrics.focusCompletionRate, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(metrics.interruptedSessions, 2)
    }

    func testZeroFocusSessionsHasZeroCompletionRate() {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let metrics = AnalyticsAggregator.metrics(records: [], range: .allTime, now: now, calendar: calendar)
        XCTAssertEqual(metrics.focusCompletionRate, 0)
        XCTAssertEqual(metrics.startedFocusSessions, 0)
    }

    func testSkippedFocusCountsAsInterruptedButNotCompleted() {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let record = makeSnapshot(
            outcome: .skipped,
            startedAt: now.addingTimeInterval(-45),
            plannedDuration: 1_500,
            activeDuration: 45
        )

        let metrics = AnalyticsAggregator.metrics(
            records: [record],
            range: .allTime,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(metrics.focusedTime, 45)
        XCTAssertEqual(metrics.startedFocusSessions, 1)
        XCTAssertEqual(metrics.completedFocusSessions, 0)
        XCTAssertEqual(metrics.focusCompletionRate, 0)
        XCTAssertEqual(metrics.interruptedSessions, 1)
    }

    func testShortLongBreakAndEmergencyMetricsRemainDistinct() {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let records = [
            makeSnapshot(mode: .shortBreak, outcome: .completed, startedAt: now.addingTimeInterval(-300), activeDuration: 60),
            makeSnapshot(mode: .longBreak, outcome: .completed, startedAt: now.addingTimeInterval(-200), activeDuration: 120),
            makeSnapshot(mode: .longBreak, outcome: .emergencyExit, startedAt: now.addingTimeInterval(-100), activeDuration: 20)
        ]
        let metrics = AnalyticsAggregator.metrics(records: records, range: .allTime, now: now, calendar: calendar)

        XCTAssertEqual(metrics.shortBreakTime, 60)
        XCTAssertEqual(metrics.longBreakTime, 140)
        XCTAssertEqual(metrics.completedShortBreaks, 1)
        XCTAssertEqual(metrics.completedLongBreaks, 1)
        XCTAssertEqual(metrics.emergencyExits, 1)
        XCTAssertEqual(metrics.interruptedSessions, 1)
    }

    func testDateRangesUseLocalCalendarBoundaries() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 12)) ?? Date()
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 1)) ?? now
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? now
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? now
        let records = [today, sixDaysAgo, sevenDaysAgo].map {
            makeSnapshot(startedAt: $0, activeDuration: 60)
        }

        XCTAssertEqual(
            AnalyticsAggregator.metrics(records: records, range: .today, now: now, calendar: calendar).startedFocusSessions,
            1
        )
        XCTAssertEqual(
            AnalyticsAggregator.metrics(records: records, range: .last7Days, now: now, calendar: calendar).startedFocusSessions,
            2
        )
        XCTAssertEqual(
            AnalyticsAggregator.metrics(records: records, range: .allTime, now: now, calendar: calendar).startedFocusSessions,
            3
        )
    }

    func testFocusTimeGroupsByLocalStartDayAndSortsDays() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 12)) ?? Date()
        let dayOneMorning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 9)) ?? now
        let dayOneAfternoon = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 15)) ?? now
        let dayTwo = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 9)) ?? now
        let records = [
            makeSnapshot(startedAt: dayTwo, activeDuration: 180),
            makeSnapshot(startedAt: dayOneMorning, activeDuration: 60),
            makeSnapshot(startedAt: dayOneAfternoon, activeDuration: 120)
        ]

        let daily = AnalyticsAggregator.metrics(records: records, range: .allTime, now: now, calendar: calendar).dailyFocusTime
        XCTAssertEqual(daily.count, 2)
        XCTAssertLessThan(daily[0].date, daily[1].date)
        XCTAssertEqual(daily[0].duration, 180)
        XCTAssertEqual(daily[1].duration, 180)
    }

    func testAverageBreakDeferralUsesScheduledAndActualStart() {
        let scheduled = Date(timeIntervalSince1970: 1_720_000_000)
        let records = [
            makeSnapshot(mode: .shortBreak, origin: .automatic, startedAt: scheduled.addingTimeInterval(30), scheduledAt: scheduled),
            makeSnapshot(mode: .longBreak, origin: .automatic, startedAt: scheduled.addingTimeInterval(90), scheduledAt: scheduled),
            makeSnapshot(mode: .shortBreak, origin: .manual, startedAt: scheduled)
        ]

        let metrics = AnalyticsAggregator.metrics(
            records: records,
            range: .allTime,
            now: scheduled.addingTimeInterval(10_000),
            calendar: calendar
        )
        XCTAssertEqual(metrics.averageBreakDeferral ?? -1, 60, accuracy: 0.001)
    }

    func testAnalyticsStorePersistsTypedFieldsAndPreventsDuplicateIDs() throws {
        let store = try makeStore()
        let start = Date(timeIntervalSince1970: 1_720_000_000)
        let snapshot = makeSnapshot(
            mode: .longBreak,
            origin: .automatic,
            outcome: .emergencyExit,
            startedAt: start,
            activeDuration: 42,
            scheduledAt: start.addingTimeInterval(-30),
            cyclePosition: 4
        )

        store.record(snapshot)
        store.record(snapshot)

        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records[0], snapshot)
        XCTAssertNil(store.errorMessage)
    }

    func testAnalyticsStoreRoundTripsSkippedOutcome() throws {
        let store = try makeStore()
        let start = Date(timeIntervalSince1970: 1_720_000_000)
        store.record(makeSnapshot(outcome: .skipped, startedAt: start, activeDuration: 42))

        store.reload()

        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records[0].outcome, .skipped)
    }

    func testAnalyticsStoreClearDeletesFinalizedRecords() throws {
        let store = try makeStore()
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        store.record(makeSnapshot(startedAt: now))
        store.record(makeSnapshot(mode: .shortBreak, startedAt: now))
        XCTAssertEqual(store.records.count, 2)

        store.clear()

        XCTAssertTrue(store.records.isEmpty)
        store.reload()
        XCTAssertTrue(store.records.isEmpty)
    }

    func testClearingAnalyticsDoesNotInterruptRunningSession() throws {
        let store = try makeStore()
        let harness = ControllerHarness()
        harness.startFocus()
        let before = harness.controller.state

        store.clear()

        XCTAssertEqual(harness.controller.state, before)
        XCTAssertTrue(harness.scheduler.isScheduled)
    }

    func testControllerRecordsEverySupportedOutcomeExactlyOnce() {
        let completed = ControllerHarness { $0.automaticallyStartBreaks = false }
        completed.completeFocus()
        XCTAssertEqual(completed.recorder.records.map(\.outcome), [.completed])

        let stopped = ControllerHarness()
        stopped.startFocus()
        stopped.controller.stopCurrentSession()
        XCTAssertEqual(stopped.recorder.records.map(\.outcome), [.stopped])

        let skipped = ControllerHarness()
        skipped.startFocus()
        skipped.controller.requestSkipFocus()
        skipped.controller.confirmSkipFocus()
        XCTAssertEqual(skipped.recorder.records.map(\.outcome), [.skipped])

        let switched = ControllerHarness()
        switched.startFocus()
        switched.controller.requestModeSwitch(to: .shortBreak)
        switched.controller.confirmModeSwitch()
        XCTAssertEqual(switched.recorder.records.map(\.outcome), [.switchedMode])

        let emergency = ControllerHarness()
        emergency.controller.selectMode(.shortBreak)
        emergency.controller.startSelectedMode()
        emergency.controller.requestEmergencyExit()
        emergency.controller.confirmEmergencyExit()
        XCTAssertEqual(emergency.recorder.records.map(\.outcome), [.emergencyExit])
    }

    private func makeStore() throws -> AnalyticsStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SessionRecord.self, configurations: configuration)
        return AnalyticsStore(modelContainer: container)
    }
}

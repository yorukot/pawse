import Foundation

enum AnalyticsDateRange: String, CaseIterable, Identifiable, Sendable {
    case today
    case last7Days
    case last30Days
    case allTime

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .today: "Today"
        case .last7Days: "Last 7 Days"
        case .last30Days: "Last 30 Days"
        case .allTime: "All Time"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "calendar"
        case .last7Days: "calendar.badge.clock"
        case .last30Days: "calendar.badge.clock"
        case .allTime: "clock.arrow.circlepath"
        }
    }

    func startDate(now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today: return today
        case .last7Days: return calendar.date(byAdding: .day, value: -6, to: today)
        case .last30Days: return calendar.date(byAdding: .day, value: -29, to: today)
        case .allTime: return nil
        }
    }
}

struct DailyFocusTime: Equatable, Identifiable, Sendable {
    let date: Date
    let duration: TimeInterval
    var id: Date { date }
}

struct AnalyticsMetrics: Equatable, Sendable {
    let focusedTime: TimeInterval
    let completedFocusSessions: Int
    let startedFocusSessions: Int
    let focusCompletionRate: Double
    let shortBreakTime: TimeInterval
    let longBreakTime: TimeInterval
    let completedShortBreaks: Int
    let completedLongBreaks: Int
    let interruptedSessions: Int
    let emergencyExits: Int
    let averageBreakDeferral: TimeInterval?
    let dailyFocusTime: [DailyFocusTime]
    let recentSessions: [SessionRecordSnapshot]
}

enum AnalyticsAggregator {
    static func metrics(
        records: [SessionRecordSnapshot],
        range: AnalyticsDateRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AnalyticsMetrics {
        let startDate = range.startDate(now: now, calendar: calendar)
        let filtered = records.filter { record in
            guard record.startedAt <= now else { return false }
            guard let startDate else { return true }
            return record.startedAt >= startDate
        }
        let focusRecords = filtered.filter { $0.mode == .focus }
        let shortBreakRecords = filtered.filter { $0.mode == .shortBreak }
        let longBreakRecords = filtered.filter { $0.mode == .longBreak }
        let completedFocus = focusRecords.filter { $0.outcome == .completed }.count
        let completionRate = focusRecords.isEmpty
            ? 0
            : Double(completedFocus) / Double(focusRecords.count)
        let deferrals = filtered.compactMap { record -> TimeInterval? in
            guard record.mode.isBreak, let scheduledAt = record.scheduledAt else { return nil }
            return max(0, record.startedAt.timeIntervalSince(scheduledAt))
        }

        let daily = Dictionary(grouping: focusRecords, by: { calendar.startOfDay(for: $0.startedAt) })
            .map { day, records in
                DailyFocusTime(
                    date: day,
                    duration: records.reduce(0) { $0 + $1.activeDuration }
                )
            }
            .sorted { $0.date < $1.date }

        return AnalyticsMetrics(
            focusedTime: focusRecords.reduce(0) { $0 + $1.activeDuration },
            completedFocusSessions: completedFocus,
            startedFocusSessions: focusRecords.count,
            focusCompletionRate: completionRate,
            shortBreakTime: shortBreakRecords.reduce(0) { $0 + $1.activeDuration },
            longBreakTime: longBreakRecords.reduce(0) { $0 + $1.activeDuration },
            completedShortBreaks: shortBreakRecords.filter { $0.outcome == .completed }.count,
            completedLongBreaks: longBreakRecords.filter { $0.outcome == .completed }.count,
            interruptedSessions: filtered.filter(isInterrupted).count,
            emergencyExits: filtered.filter { $0.mode.isBreak && $0.outcome == .emergencyExit }.count,
            averageBreakDeferral: deferrals.isEmpty ? nil : deferrals.reduce(0, +) / Double(deferrals.count),
            dailyFocusTime: daily,
            recentSessions: filtered.sorted { $0.endedAt > $1.endedAt }
        )
    }

    private static func isInterrupted(_ record: SessionRecordSnapshot) -> Bool {
        if record.mode == .focus {
            return record.outcome == .stopped || record.outcome == .switchedMode
        }
        return record.outcome == .emergencyExit || record.outcome == .stopped
    }
}

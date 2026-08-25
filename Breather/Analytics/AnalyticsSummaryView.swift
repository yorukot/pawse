import SwiftUI

struct AnalyticsSummaryView: View {
    let metrics: AnalyticsMetrics

    var body: some View {
        GroupBox("Summary") {
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                GridRow {
                    metric("Focused Time", duration: metrics.focusedTime)
                    metric("Completed Focus", value: "\(metrics.completedFocusSessions)")
                    metric("Completion Rate", value: metrics.focusCompletionRate.formatted(.percent.precision(.fractionLength(0))))
                }
                Divider().gridCellColumns(3)
                GridRow {
                    metric("Short Break Time", duration: metrics.shortBreakTime)
                    metric("Long Break Time", duration: metrics.longBreakTime)
                    metric("Interrupted", value: "\(metrics.interruptedSessions)")
                }
                GridRow {
                    metric("Completed Short Breaks", value: "\(metrics.completedShortBreaks)")
                    metric("Completed Long Breaks", value: "\(metrics.completedLongBreaks)")
                    metric("Emergency Exits", value: "\(metrics.emergencyExits)")
                }
                if let deferral = metrics.averageBreakDeferral {
                    Divider().gridCellColumns(3)
                    GridRow {
                        metric("Average Break Deferral", duration: deferral)
                            .gridCellColumns(3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func metric(_ title: String, duration: TimeInterval) -> some View {
        metric(title, value: analyticsDuration(duration))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func analyticsDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

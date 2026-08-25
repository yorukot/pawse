import Charts
import SwiftUI

struct FocusTimeChart: View {
    let values: [DailySessionTime]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AnalyticsSectionHeader(
                title: "Focus and Break Time by Day",
                systemImage: "chart.bar.fill"
            )

            AnalyticsCard {
                HStack(spacing: 18) {
                    legendItem("Focus", color: Color.accentColor)
                    legendItem("Break", color: PawseTheme.Colors.pumpkin)
                    Spacer()
                    Text("Minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Chart(chartValues) { value in
                    BarMark(
                        x: .value(String(localized: "Day", locale: locale), value.date, unit: .day),
                        y: .value(
                            String(localized: "Minutes", locale: locale),
                            value.duration / 60
                        )
                    )
                    .position(
                        by: .value(
                            String(localized: "Mode", locale: locale),
                            LocalizationText.string(value.kind.displayName, locale: locale)
                        )
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: value.kind.gradientColors,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(5)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(values.count, 7))) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.primary.opacity(0.05))
                        AxisTick()
                            .foregroundStyle(.secondary)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.primary.opacity(0.10))
                        AxisValueLabel()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 220)
                .accessibilityLabel("Focus and Break Time by Day")
                .accessibilityValue(chartSummary)
            }
        }
    }

    private var chartValues: [SessionTimeValue] {
        values.flatMap { value in
            [
                SessionTimeValue(
                    date: value.date,
                    duration: value.focusDuration,
                    kind: .focus
                ),
                SessionTimeValue(
                    date: value.date,
                    duration: value.breakDuration,
                    kind: .breakTime
                )
            ]
        }
    }

    private var chartSummary: Text {
        let focusTime = DurationFormatter.spoken(
            values.reduce(0) { $0 + $1.focusDuration },
            locale: locale
        )
        let breakTime = DurationFormatter.spoken(
            values.reduce(0) { $0 + $1.breakDuration },
            locale: locale
        )
        return Text("Focus")
            + Text(verbatim: ": \(focusTime). ")
            + Text("Break")
            + Text(verbatim: ": \(breakTime).")
    }

    private func legendItem(_ title: LocalizedStringResource, color: Color) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 11, height: 11)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SessionTimeValue: Identifiable {
    let date: Date
    let duration: TimeInterval
    let kind: SessionTimeKind

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(kind.rawValue)"
    }
}

private enum SessionTimeKind: String {
    case focus
    case breakTime

    var displayName: LocalizedStringResource {
        switch self {
        case .focus: "Focus"
        case .breakTime: "Break"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .focus: [Color.accentColor, PawseTheme.Colors.lake]
        case .breakTime: [PawseTheme.Colors.pumpkin, PawseTheme.Colors.pumpkin.opacity(0.55)]
        }
    }
}

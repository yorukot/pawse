import Charts
import SwiftUI

struct FocusTimeChart: View {
    let values: [DailyFocusTime]
    @Environment(\.locale) private var locale

    var body: some View {
        GroupBox("Focus Time by Day") {
            Chart(values) { value in
                BarMark(
                    x: .value(String(localized: "Day", locale: locale), value.date, unit: .day),
                    y: .value(String(localized: "Focused Minutes", locale: locale), value.duration / 60)
                )
                .foregroundStyle(Color.accentColor)
            }
            .chartYAxisLabel("Minutes")
            .frame(height: 190)
            .padding(.top, 6)
            .accessibilityLabel("Focus time by day")
            .accessibilityValue(Text(chartSummary))
        }
    }

    private var chartSummary: LocalizedStringResource {
        guard !values.isEmpty else { return "No focused time in this range" }
        let focusedTime = DurationFormatter.spoken(
            values.reduce(0) { $0 + $1.duration },
            locale: locale
        )
        if values.count == 1 {
            return "Focused time: \(focusedTime) in one day"
        }
        return "Focused time: \(focusedTime) across \(values.count) days"
    }
}

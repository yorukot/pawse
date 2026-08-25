import Charts
import SwiftUI

struct FocusTimeChart: View {
    let values: [DailyFocusTime]

    var body: some View {
        GroupBox("Focus Time by Day") {
            Chart(values) { value in
                BarMark(
                    x: .value("Day", value.date, unit: .day),
                    y: .value("Focused Minutes", value.duration / 60)
                )
                .foregroundStyle(Color.accentColor)
            }
            .chartYAxisLabel("Minutes")
            .frame(height: 190)
            .padding(.top, 6)
            .accessibilityLabel("Focus time by day")
            .accessibilityValue(chartSummary)
        }
    }

    private var chartSummary: String {
        guard !values.isEmpty else { return "No focused time in this range" }
        let minutes = Int(values.reduce(0) { $0 + $1.duration } / 60)
        return "\(minutes) focused minutes across \(values.count) days"
    }
}

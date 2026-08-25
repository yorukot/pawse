import SwiftUI

struct RecentSessionsTable: View {
    let records: [SessionRecordSnapshot]
    @Environment(\.locale) private var locale

    var body: some View {
        GroupBox("Recent Sessions") {
            Table(records) {
                TableColumn("Date") { record in
                    Text(record.startedAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)
                    ))
                }
                .width(min: 145, ideal: 170)
                TableColumn("Mode") { record in
                    Label {
                        Text(record.mode.displayName)
                    } icon: {
                        Image(systemName: record.mode.symbolName)
                    }
                }
                .width(min: 110, ideal: 135)
                TableColumn("Planned") { record in
                    Text(DurationFormatter.timer(record.plannedDuration))
                        .monospacedDigit()
                }
                .width(80)
                TableColumn("Actual") { record in
                    Text(DurationFormatter.timer(record.activeDuration))
                        .monospacedDigit()
                }
                .width(80)
                TableColumn("Outcome") { record in
                    Text(outcomeName(record.outcome))
                }
                .width(min: 100, ideal: 120)
            }
            .frame(minHeight: 210)
        }
    }

    private func outcomeName(_ outcome: SessionOutcome) -> LocalizedStringResource {
        switch outcome {
        case .completed: "Completed"
        case .skipped: "Skipped"
        case .stopped: "Stopped"
        case .switchedMode: "Switched Mode"
        case .emergencyExit: "Emergency Exit"
        }
    }
}

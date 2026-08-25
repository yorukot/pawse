import SwiftUI

struct RecentSessionsTable: View {
    let records: [SessionRecordSnapshot]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AnalyticsSectionHeader(title: "Recent Sessions", systemImage: "clock.arrow.circlepath")

            Table(records) {
                TableColumn("Date") { record in
                    Text(record.startedAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)
                    ))
                    .lineLimit(1)
                }
                .width(min: 145, ideal: 170)
                TableColumn("Mode") { record in
                    Label {
                        Text(record.mode.displayName)
                    } icon: {
                        Image(systemName: record.mode.symbolName)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(modeColor(record.mode))
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
                    HStack(spacing: 7) {
                        Circle()
                            .fill(outcomeColor(record.outcome))
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                        Text(outcomeName(record.outcome))
                    }
                }
                .width(min: 100, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 230, idealHeight: 270, maxHeight: 310)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func modeColor(_ mode: SessionMode) -> Color {
        switch mode {
        case .focus: Color.accentColor
        case .shortBreak: PawseTheme.Colors.lake
        case .longBreak: PawseTheme.Colors.mountain
        }
    }

    private func outcomeColor(_ outcome: SessionOutcome) -> Color {
        switch outcome {
        case .completed: .green
        case .skipped: PawseTheme.Colors.pumpkin
        case .stopped: .secondary
        case .switchedMode: Color.accentColor
        case .emergencyExit: .red
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

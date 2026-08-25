import SwiftUI

struct AnalyticsView: View {
    @Bindable var store: AnalyticsStore
    let persistenceNotice: LocalizedStringResource?
    @Environment(\.locale) private var locale
    @State private var selectedRange: AnalyticsDateRange = .last7Days
    @State private var confirmsClear = false

    private var metrics: AnalyticsMetrics {
        AnalyticsAggregator.metrics(records: store.records, range: selectedRange)
    }

    var body: some View {
        analyticsContent
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem {
                    Picker("Date Range", selection: $selectedRange) {
                        ForEach(AnalyticsDateRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityLabel("Analytics date range")
                }
                ToolbarItem {
                    Button("Clear Analytics Data…", role: .destructive) {
                        confirmsClear = true
                    }
                    .disabled(store.records.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let message = store.errorMessage ?? persistenceNotice {
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
            .confirmationDialog(
                "Clear Analytics Data?",
                isPresented: $confirmsClear,
                titleVisibility: .visible
            ) {
                Button("Clear Analytics Data", role: .destructive) {
                    store.clear()
                }
            } message: {
                Text("This deletes finalized session history. Settings and the Focus cycle will not change.")
            }
    }

    @ViewBuilder
    private var analyticsContent: some View {
        if metrics.recentSessions.isEmpty {
            let rangeName = LocalizationText.string(selectedRange.displayName, locale: locale)
            ContentUnavailableView(
                String(localized: "No Sessions in \(rangeName)", locale: locale),
                systemImage: "chart.bar",
                description: Text("Completed and interrupted sessions will appear here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    AnalyticsSummaryView(metrics: metrics)
                    FocusTimeChart(values: metrics.dailyFocusTime)
                    RecentSessionsTable(records: metrics.recentSessions)
                }
                .padding(20)
            }
        }
    }
}

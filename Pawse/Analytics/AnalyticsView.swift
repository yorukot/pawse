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
                    Button(role: .destructive) {
                        confirmsClear = true
                    } label: {
                        Label("Clear Analytics Data…", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .help(Text("Clear Analytics Data…"))
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
                LazyVStack(alignment: .leading, spacing: 22) {
                    AnalyticsSummaryView(metrics: metrics)
                    FocusTimeChart(values: metrics.dailySessionTime)
                    RecentSessionsTable(records: metrics.recentSessions)
                }
                .frame(maxWidth: 1_040)
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
            }
            .background {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.045), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
    }
}

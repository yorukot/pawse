import SwiftUI

struct AnalyticsView: View {
    @Bindable var store: AnalyticsStore
    let persistenceNotice: String?
    @State private var selectedRange: AnalyticsDateRange = .last7Days
    @State private var confirmsClear = false

    private var metrics: AnalyticsMetrics {
        AnalyticsAggregator.metrics(records: store.records, range: selectedRange)
    }

    var body: some View {
        NavigationSplitView {
            List(
                AnalyticsDateRange.allCases,
                selection: Binding(
                    get: { Optional(selectedRange) },
                    set: { if let range = $0 { selectedRange = range } }
                )
            ) { range in
                Label(range.displayName, systemImage: range.symbolName)
                    .tag(range)
            }
            .listStyle(.sidebar)
            .navigationTitle("Analytics")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            analyticsContent
                .navigationTitle(selectedRange.displayName)
                .toolbar {
                    ToolbarItem {
                        Button("Clear Analytics Data…", role: .destructive) {
                            confirmsClear = true
                        }
                        .disabled(store.records.isEmpty)
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 820, minHeight: 560)
        .safeAreaInset(edge: .bottom) {
            if let message = store.errorMessage ?? persistenceNotice {
                Label(message, systemImage: "exclamationmark.triangle")
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
        Group {
            if metrics.recentSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions in This Range",
                    systemImage: "chart.bar",
                    description: Text("Completed and interrupted sessions will appear here.")
                )
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
}

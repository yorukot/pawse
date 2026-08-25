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
        .navigationTitle("Analytics")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Date Range", selection: $selectedRange) {
                    ForEach(AnalyticsDateRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)
            }
            ToolbarItem {
                Button("Clear Analytics Data…", role: .destructive) {
                    confirmsClear = true
                }
                .disabled(store.records.isEmpty)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = store.errorMessage ?? persistenceNotice {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
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
}

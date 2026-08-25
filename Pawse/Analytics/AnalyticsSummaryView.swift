import SwiftUI

struct AnalyticsSummaryView: View {
    let metrics: AnalyticsMetrics
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AnalyticsSectionHeader(title: "Summary", systemImage: "sparkles")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    focusCard
                        .frame(minWidth: 340)
                    completionCard
                        .frame(width: 190)
                }

                VStack(spacing: 12) {
                    focusCard
                    completionCard
                }
            }

            ViewThatFits(in: .horizontal) {
                LazyVGrid(columns: threeColumnGrid, spacing: 12) {
                    supportingMetrics
                }

                LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                    supportingMetrics
                }
            }
        }
    }

    private var focusCard: some View {
        AnalyticsCard(accent: Color.accentColor) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Focused Time")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(DurationFormatter.analytics(metrics.focusedTime, locale: locale))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "timer")
                        .font(.system(size: 24, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 48, height: 48)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)
                }

                Divider()

                HStack(spacing: 32) {
                    compactFocusMetric(
                        "Completed Focus",
                        value: metrics.completedFocusSessions
                    )
                    compactFocusMetric(
                        "Interrupted",
                        value: metrics.interruptedSessions
                    )
                }
            }
            .frame(minHeight: 126, alignment: .top)
        }
    }

    private var completionCard: some View {
        AnalyticsCard(accent: PawseTheme.Colors.lake) {
            VStack(spacing: 12) {
                Text("Completion Rate")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: min(max(metrics.focusCompletionRate, 0), 1))
                        .stroke(
                            PawseTheme.Colors.lake,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text(completionRate)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(width: 86, height: 86)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .top)
            .accessibilityElement(children: .combine)
        }
    }

    private var completionRate: String {
        metrics.focusCompletionRate.formatted(
            .percent.precision(.fractionLength(0)).locale(locale)
        )
    }

    private func compactFocusMetric(
        _ title: LocalizedStringResource,
        value: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func breakMetric(
        _ title: LocalizedStringResource,
        duration: TimeInterval,
        detailTitle: LocalizedStringResource,
        detailValue: Int,
        symbol: String,
        tint: Color
    ) -> some View {
        AnalyticsCard(verticalPadding: 12) {
            HStack(alignment: .center, spacing: 12) {
                metricIcon(symbol, tint: tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(DurationFormatter.analytics(duration, locale: locale))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 5) {
                        Text(detailTitle)
                        Text("\(detailValue)")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(height: 64, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func compactMetric(
        _ title: LocalizedStringResource,
        value: String,
        symbol: String,
        tint: Color
    ) -> some View {
        AnalyticsCard(verticalPadding: 12) {
            HStack(alignment: .center, spacing: 12) {
                metricIcon(symbol, tint: tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(height: 64, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func metricIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }

    private var threeColumnGrid: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 170), spacing: 12), count: 3)
    }

    private var twoColumnGrid: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 170), spacing: 12), count: 2)
    }

    @ViewBuilder
    private var supportingMetrics: some View {
        breakMetric(
            "Short Break Time",
            duration: metrics.shortBreakTime,
            detailTitle: "Completed Short Breaks",
            detailValue: metrics.completedShortBreaks,
            symbol: "cup.and.saucer.fill",
            tint: PawseTheme.Colors.lake
        )
        breakMetric(
            "Long Break Time",
            duration: metrics.longBreakTime,
            detailTitle: "Completed Long Breaks",
            detailValue: metrics.completedLongBreaks,
            symbol: "figure.walk",
            tint: PawseTheme.Colors.mountain
        )
        compactMetric(
            "Emergency Exits",
            value: "\(metrics.emergencyExits)",
            symbol: "door.left.hand.open",
            tint: .secondary
        )
    }
}

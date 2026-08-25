import SwiftUI

struct BreakReminderView: View {
    static let attentionInterval: TimeInterval = 15

    let mode: SessionMode
    let scheduledAt: Date
    let onStart: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let progress = Self.attentionProgress(scheduledAt: scheduledAt, now: timeline.date)
            let isUrgent = Self.isUrgent(scheduledAt: scheduledAt, now: timeline.date)
            let pulseOpacity = urgentPulseOpacity(at: timeline.date, isUrgent: isUrgent)

            Button(action: onStart) {
                VStack(spacing: 7) {
                    Text(mode == .longBreak ? "Long break soon" : "Break soon")
                        .font(.system(size: 17, weight: .semibold))
                    Text(isUrgent ? "Ready when you pause — click to start" : "Click to start")
                        .font(.system(size: 13))
                        .foregroundStyle(isUrgent ? .primary : .secondary)
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(isUrgent ? .orange : .accentColor)
                        .accessibilityLabel("Break reminder attention")
                        .accessibilityValue(isUrgent ? "Ready" : "\(Int(progress * 100)) percent")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isUrgent ? Color.orange.opacity(pulseOpacity) : Color.white.opacity(0.16),
                        lineWidth: isUrgent ? 2 : 1
                    )
            }
            .shadow(color: isUrgent ? .orange.opacity(0.18 * pulseOpacity) : .black.opacity(0.2), radius: 14)
            .accessibilityLabel(
                mode == .longBreak
                    ? "Long break ready. Click to start."
                    : "Short break ready. Click to start."
            )
        }
    }

    private func urgentPulseOpacity(at date: Date, isUrgent: Bool) -> Double {
        guard isUrgent else { return 0.16 }
        guard !reduceMotion else { return 0.9 }
        let phase = sin(date.timeIntervalSinceReferenceDate * 2 * .pi)
        return 0.55 + ((phase + 1) / 2) * 0.4
    }

    static func attentionProgress(scheduledAt: Date, now: Date) -> Double {
        min(1, max(0, now.timeIntervalSince(scheduledAt)) / attentionInterval)
    }

    static func isUrgent(scheduledAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(scheduledAt) >= attentionInterval
    }
}

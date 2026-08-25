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
            let isLongBreak = mode == .longBreak

            Button(action: onStart) {
                VStack(spacing: 10) {
                    if isUrgent {
                        HStack {
                            Label(isLongBreak ? "LONG BREAK READY" : "BREAK READY", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .tracking(0.8)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(.red.opacity(0.82), in: Capsule())
                                .scaleEffect(reduceMotion ? 1 : 1 + (pulseOpacity - 0.55) * 0.025)

                            Spacer(minLength: 8)

                            Text(isLongBreak ? "START LONG BREAK  →" : "START BREAK  →")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(.white, in: Capsule())
                        }
                    }

                    Text(isUrgent
                         ? (isLongBreak ? "Take your long break now" : "Take your break now")
                         : (isLongBreak ? "Long break soon" : "Break soon"))
                        .font(.system(size: isUrgent ? 21 : 17, weight: .bold, design: .rounded))
                        .foregroundStyle(isUrgent ? .white : .primary)

                    Text(isUrgent ? "Your break is waiting — click to start" : "Click to start")
                        .font(.system(size: 13, weight: isUrgent ? .medium : .regular))
                        .foregroundStyle(isUrgent ? .white.opacity(0.9) : .secondary)

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(isUrgent ? .white : .accentColor)
                        .scaleEffect(x: 1, y: isUrgent ? 1.45 : 1, anchor: .center)
                        .accessibilityLabel("Break reminder attention")
                        .accessibilityValue(isUrgent ? "Ready" : "\(Int(progress * 100)) percent")

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                isUrgent
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.31, green: 0.08, blue: 0.06), Color(red: 0.16, green: 0.12, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isUrgent ? Color.orange.opacity(pulseOpacity) : Color.white.opacity(0.16),
                        lineWidth: isUrgent ? 3 : 1
                    )
            }
            .shadow(color: isUrgent ? .red.opacity(0.42 * pulseOpacity) : .black.opacity(0.2), radius: isUrgent ? 22 : 14)
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

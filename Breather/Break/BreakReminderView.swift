import SwiftUI

struct BreakReminderView: View {
    static let attentionInterval: TimeInterval = 15
    static let pulseInterval: TimeInterval = 1.2

    let mode: SessionMode
    let scheduledAt: Date
    let onStart: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let progress = Self.attentionProgress(scheduledAt: scheduledAt, now: timeline.date)
            let isAttentionState = Self.isAttentionState(scheduledAt: scheduledAt, now: timeline.date)
            let pulse = Self.attentionPulse(at: timeline.date, isAttentionState: isAttentionState)

            Button(action: onStart) {
                VStack(spacing: 9) {
                    HStack(spacing: 12) {
                        logo(pulse: pulse, isAttentionState: isAttentionState)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.title(for: mode, isAttentionState: isAttentionState))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Click to start")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 25, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                isAttentionState
                                    ? BreatherTheme.Colors.terracotta
                                    : Color.secondary
                            )
                            .accessibilityHidden(true)
                    }

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(BreatherTheme.Colors.terracotta)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background {
                RoundedRectangle(
                    cornerRadius: BreatherTheme.Metrics.reminderCornerRadius,
                    style: .continuous
                )
                .fill(
                    isAttentionState
                        ? BreatherTheme.Colors.terracotta.opacity(0.05 + pulse * 0.05)
                        : Color.clear
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: BreatherTheme.Metrics.reminderCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isAttentionState
                        ? BreatherTheme.Colors.terracotta.opacity(0.58 + pulse * 0.34)
                        : Color.primary.opacity(0.13),
                    lineWidth: isAttentionState ? 2 : 1
                )
            }
            .accessibilityLabel(Self.accessibilityLabel(
                for: mode,
                isAttentionState: isAttentionState
            ))
            .accessibilityHint("Starts the break")
        }
    }

    private func logo(pulse: Double, isAttentionState: Bool) -> some View {
        ZStack {
            Circle()
                .fill(BreatherTheme.Colors.cream.opacity(0.94))

            Image("BreatherLogo")
                .resizable()
                .scaledToFit()
                .padding(4)
        }
        .frame(
            width: BreatherTheme.Metrics.reminderLogoSize,
            height: BreatherTheme.Metrics.reminderLogoSize
        )
        .scaleEffect(Self.logoScale(
            pulse: pulse,
            isAttentionState: isAttentionState,
            reduceMotion: reduceMotion
        ))
        .accessibilityHidden(true)
    }

    static func title(for mode: SessionMode, isAttentionState: Bool) -> String {
        switch (mode, isAttentionState) {
        case (.longBreak, false): "Long break soon"
        case (.longBreak, true): "Long break ready"
        case (_, false): "Break soon"
        case (_, true): "Break ready"
        }
    }

    static func accessibilityLabel(for mode: SessionMode, isAttentionState: Bool) -> String {
        let modeTitle = mode == .longBreak ? "Long break" : "Short break"
        let stateTitle = isAttentionState ? "ready" : "soon"
        return "\(modeTitle) \(stateTitle). Click to start."
    }

    static func attentionProgress(scheduledAt: Date, now: Date) -> Double {
        min(1, max(0, now.timeIntervalSince(scheduledAt)) / attentionInterval)
    }

    static func isAttentionState(scheduledAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(scheduledAt) >= attentionInterval
    }

    static func attentionPulse(at date: Date, isAttentionState: Bool) -> Double {
        guard isAttentionState else { return 0 }
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: pulseInterval)
        return (sin((phase / pulseInterval) * 2 * .pi - (.pi / 2)) + 1) / 2
    }

    static func logoScale(pulse: Double, isAttentionState: Bool, reduceMotion: Bool) -> Double {
        guard isAttentionState, !reduceMotion else { return 1 }
        return 1 + min(1, max(0, pulse)) * 0.06
    }
}

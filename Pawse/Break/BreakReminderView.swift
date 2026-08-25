import SwiftUI

struct BreakReminderView: View {
    static let pulseInterval: TimeInterval = 1.2

    let presentation: BreakReminderPresentation
    let onStart: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let progress = Self.progress(for: presentation.phase, now: timeline.date)
            let isAttentionState = Self.isAttentionState(presentation.phase)
            let pulse = reduceMotion
                ? 0
                : Self.attentionPulse(at: timeline.date, isAttentionState: isAttentionState)

            Button(action: onStart) {
                VStack(spacing: 9) {
                    HStack(spacing: 12) {
                        logo(pulse: pulse, isAttentionState: isAttentionState)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.title(for: presentation.mode, phase: presentation.phase))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(Self.subtitle(for: presentation.phase))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 25, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                isAttentionState
                                    ? PawseTheme.Colors.pumpkin
                                    : Color.secondary
                            )
                            .accessibilityHidden(true)
                    }

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(PawseTheme.Colors.pumpkin)
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
                    cornerRadius: PawseTheme.Metrics.reminderCornerRadius,
                    style: .continuous
                )
                .fill(
                    isAttentionState
                        ? PawseTheme.Colors.pumpkin.opacity(0.05 + pulse * 0.05)
                        : Color.clear
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: PawseTheme.Metrics.reminderCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isAttentionState
                        ? PawseTheme.Colors.pumpkin.opacity(0.58 + pulse * 0.34)
                        : Color.primary.opacity(0.13),
                    lineWidth: isAttentionState ? 2 : 1
                )
            }
            .accessibilityLabel(Text(Self.accessibilityLabel(for: presentation)))
            .accessibilityHint("Starts the break")
        }
    }

    private func logo(pulse: Double, isAttentionState: Bool) -> some View {
        Image("PawseHUDMascot")
            .resizable()
            .scaledToFit()
            .frame(
                width: PawseTheme.Metrics.reminderMascotWidth,
                height: PawseTheme.Metrics.reminderMascotHeight
            )
            .scaleEffect(Self.logoScale(
                pulse: pulse,
                isAttentionState: isAttentionState,
                reduceMotion: reduceMotion
            ))
            .accessibilityHidden(true)
    }

    static func title(
        for mode: SessionMode,
        phase: BreakReminderPhase
    ) -> LocalizedStringResource {
        switch (mode, phase) {
        case (.longBreak, .upcoming): "Long break soon"
        case (.longBreak, .ready): "Long break ready"
        case (_, .upcoming): "Break soon"
        case (_, .ready): "Break ready"
        }
    }

    static func subtitle(for phase: BreakReminderPhase) -> LocalizedStringResource {
        switch phase {
        case .upcoming: "Click to start now"
        case .ready: "Click to start"
        }
    }

    static func accessibilityLabel(
        for presentation: BreakReminderPresentation
    ) -> LocalizedStringResource {
        switch (presentation.mode, presentation.phase) {
        case (.longBreak, .upcoming):
            "Long break soon. Click to finish Focus and start now."
        case (.longBreak, .ready):
            "Long break ready. Click to start."
        case (_, .upcoming):
            "Short break soon. Click to finish Focus and start now."
        case (_, .ready):
            "Short break ready. Click to start."
        }
    }

    static func progress(for phase: BreakReminderPhase, now: Date) -> Double {
        switch phase {
        case .upcoming(let deadline, let leadTime):
            guard leadTime > 0 else { return 1 }
            return min(1, max(0, 1 - deadline.timeIntervalSince(now) / leadTime))
        case .ready:
            return 1
        }
    }

    static func isAttentionState(_ phase: BreakReminderPhase) -> Bool {
        if case .ready = phase { return true }
        return false
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

import SwiftUI

struct BreakReminderView: View {
    let mode: SessionMode
    let onStart: @MainActor () -> Void

    var body: some View {
        Button(action: onStart) {
            VStack(spacing: 4) {
                Text(mode == .longBreak ? "Long break soon" : "Break soon")
                    .font(.system(size: 17, weight: .semibold))
                Text("Click to start")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityLabel(
            mode == .longBreak
                ? "Long break ready. Click to start."
                : "Short break ready. Click to start."
        )
    }
}

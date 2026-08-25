import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let controller = model.controller
        CountdownRingIcon(
            fractionRemaining: model.settings.showSessionProgressInMenuBar
                ? controller.countdownFractionRemaining
                : nil
        )
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let controller = model.controller
        if case .running = controller.state {
            return "Breather, \(controller.currentMode.displayName), \(DurationFormatter.timer(controller.remainingTime)) remaining"
        }
        if case .paused = controller.state {
            return "Breather, Focus paused, \(DurationFormatter.timer(controller.remainingTime)) remaining"
        }
        if case .breakPending = controller.state {
            return "Breather, \(controller.currentMode.displayName) ready"
        }
        return "Breather, \(controller.currentMode.displayName)"
    }
}

private struct CountdownRingIcon: View {
    let fractionRemaining: Double?

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.22), lineWidth: 2)

            Circle()
                .trim(from: 0, to: fractionRemaining ?? 1)
                .stroke(
                    .primary,
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 17, height: 17)
        .accessibilityHidden(true)
    }
}

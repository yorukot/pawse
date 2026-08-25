import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let controller = model.controller
        HStack(spacing: 4) {
            CountdownRingIcon(
                symbolName: controller.currentMode.symbolName,
                fractionRemaining: controller.countdownFractionRemaining
            )
            if model.settings.showSessionProgressInMenuBar,
               case .running = controller.state {
                Text(DurationFormatter.timer(controller.remainingTime))
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let controller = model.controller
        if case .running = controller.state {
            return "Breather, \(controller.currentMode.displayName), \(DurationFormatter.timer(controller.remainingTime)) remaining"
        }
        return "Breather, \(controller.currentMode.displayName)"
    }
}

private struct CountdownRingIcon: View {
    let symbolName: String
    let fractionRemaining: Double?

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.22), lineWidth: 1.5)

            if let fractionRemaining {
                Circle()
                    .trim(from: 0, to: fractionRemaining)
                    .stroke(
                        .primary,
                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: symbolName)
                .font(.system(size: 8, weight: .semibold))
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

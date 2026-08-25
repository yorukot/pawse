import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let controller = model.controller
        HStack(spacing: 4) {
            Image(systemName: controller.currentMode.symbolName)
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

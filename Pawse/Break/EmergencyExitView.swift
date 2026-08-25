import SwiftUI

struct EmergencyExitView: View {
    let controller: SessionController

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("End This Break Early?")
                .font(.title2.weight(.semibold))
            Text("The break will be recorded as interrupted.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Continue Break") {
                    controller.cancelEmergencyExit()
                }
                .keyboardShortcut(.cancelAction)
                Button("Emergency Exit", role: .destructive) {
                    controller.confirmEmergencyExit()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Confirm Emergency Exit")
            }
        }
        .padding(28)
        .frame(width: 390)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.14))
        }
        .accessibilityElement(children: .contain)
    }
}

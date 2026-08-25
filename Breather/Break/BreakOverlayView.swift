import SwiftUI

struct BreakOverlayView: View {
    let mode: SessionMode
    let controller: SessionController
    let settings: SettingsStore

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .overlay(Color.black.opacity(0.9))
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Label(mode.displayName, systemImage: mode.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)

                if settings.showCountdownDuringBreak {
                    Text(DurationFormatter.timer(controller.remainingTime))
                        .font(.system(size: 76, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .accessibilityLabel("\(DurationFormatter.timer(controller.remainingTime)) remaining")
                }

                Text(mode.breakMessage)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .accessibilityElement(children: .contain)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button("Emergency Exit", role: .destructive) {
                        controller.requestEmergencyExit()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.large)
                    .accessibilityLabel("Emergency Exit")
                }
            }
            .padding(32)

            if controller.isEmergencyExitConfirmationPresented {
                Color.black.opacity(0.62).ignoresSafeArea()
                EmergencyExitView(controller: controller)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

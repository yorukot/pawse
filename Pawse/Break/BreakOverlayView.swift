import AppKit
import SwiftUI

struct BreakOverlayView: View {
    let mode: SessionMode
    let controller: SessionController
    let settings: SettingsStore
    let backgroundImage: NSImage?
    let presentationState: BreakPresentationState
    let onEnterDiscreetMode: @MainActor () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if presentationState.isDiscreet {
                Color.clear
                    .ignoresSafeArea()
                    .accessibilityElement()
                    .accessibilityLabel(
                        "Discreet break active. Any keyboard or mouse activity will show the Break screen."
                    )
            } else {
                visibleBreak
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var visibleBreak: some View {
        ZStack {
            breakBackground

            VStack(spacing: 22) {
                Label {
                    Text(mode.displayName)
                } icon: {
                    Image(systemName: mode.symbolName)
                }
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)

                if settings.showCountdownDuringBreak {
                    Text(DurationFormatter.timer(controller.remainingTime))
                        .font(.system(size: 76, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .accessibilityLabel(
                            Text("\(DurationFormatter.spoken(controller.remainingTime, locale: locale)) remaining")
                        )
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
                    if presentationState.isBreakCommitted {
                        Button {
                            onEnterDiscreetMode()
                        } label: {
                            Label("Discreet Mode", systemImage: "eye.slash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel("Discreet Mode")
                        .accessibilityHint(
                            "Keep the desktop visible while Pawse continues the Break."
                        )
                    }
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

    @ViewBuilder
    private var breakBackground: some View {
        if let backgroundImage {
            Image(nsImage: backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(Color.black.opacity(0.58))
                .ignoresSafeArea()
        } else {
            Color.black
                .ignoresSafeArea()
        }
    }
}

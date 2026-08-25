import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    private var controller: SessionController { model.controller }

    var body: some View {
        @Bindable var controller = controller

        VStack(alignment: .leading, spacing: 12) {
            stateContent
            Divider()
            commonActions
        }
        .padding(14)
        .frame(width: 310)
        .alert(
            "Switch Mode?",
            isPresented: Binding(
                get: { controller.modeSwitchTarget != nil },
                set: { if !$0 { controller.cancelModeSwitch() } }
            )
        ) {
            Button("Cancel", role: .cancel) { controller.cancelModeSwitch() }
            Button("Switch") { controller.confirmModeSwitch() }
        } message: {
            Text("The current Focus session will be marked as interrupted.")
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch controller.state {
        case .idle(let selectedMode):
            idleContent(selectedMode: selectedMode)
        case .running(let session):
            runningContent(session)
        case .paused(let session):
            pausedContent(session)
        case .breakPending(let pending):
            pendingContent(pending)
        case .breakEntering(let entry):
            enteringContent(entry)
        }
    }

    private func idleContent(selectedMode: SessionMode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breather").font(.headline)
            Picker(
                "Mode",
                selection: Binding(
                    get: { selectedMode },
                    set: { controller.selectMode($0) }
                )
            ) {
                ForEach(SessionMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Session mode")

            timerText(controller.remainingTime)
                .frame(maxWidth: .infinity)

            Button("Start") { controller.startSelectedMode() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityLabel("Start \(selectedMode.displayName)")
        }
    }

    private func runningContent(_ session: RunningSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(session.mode.displayName, systemImage: session.mode.symbolName)
                .font(.headline)
            timerText(controller.remainingTime).frame(maxWidth: .infinity)
            ProgressView(value: controller.progress)
                .accessibilityLabel("Session progress")
                .accessibilityValue("\(Int(controller.progress * 100)) percent")
            if session.mode == .focus {
                HStack {
                    Button("Pause") { controller.pauseFocus() }
                    Button("Stop", role: .destructive) { controller.stopCurrentSession() }
                }
                switchModeMenu
            } else {
                Text("Your break is active on every display.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pausedContent(_ session: PausedSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Focus Paused", systemImage: "pause.circle")
                .font(.headline)
            timerText(controller.remainingTime).frame(maxWidth: .infinity)
            ProgressView(value: controller.progress)
            HStack {
                Button("Resume") { controller.resumeFocus() }
                    .buttonStyle(.borderedProminent)
                Button("Stop", role: .destructive) { controller.stopCurrentSession() }
            }
            switchModeMenu
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(session.mode.displayName) paused")
    }

    private func pendingContent(_ pending: PendingBreak) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(pending.mode == .longBreak ? "Long Break Ready" : "Break Ready", systemImage: pending.mode.symbolName)
                .font(.headline)
            Text("\(pending.mode.displayName) · \(DurationFormatter.concise(pending.plannedDuration))")
            Text("Waiting for a natural stopping point…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Start Break Now") { controller.startPendingBreakNow() }
                .buttonStyle(.borderedProminent)
            Button("Cancel Break", role: .destructive) { controller.cancelPendingBreak() }
        }
    }

    private func enteringContent(_ entry: BreakEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Starting \(entry.mode.displayName)…", systemImage: entry.mode.symbolName)
                .font(.headline)
            timerText(controller.remainingTime).frame(maxWidth: .infinity)
            Text("Resume using the keyboard or pointer now to defer this break.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var switchModeMenu: some View {
        Menu("Switch Mode…") {
            Button("Short Break") { controller.requestModeSwitch(to: .shortBreak) }
            Button("Long Break") { controller.requestModeSwitch(to: .longBreak) }
        }
    }

    private var commonActions: some View {
        Group {
            Button("Analytics…") {
                openWindow(id: "analytics")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit Breather") { NSApp.terminate(nil) }
        }
    }

    private func timerText(_ duration: TimeInterval) -> some View {
        Text(DurationFormatter.timer(duration))
            .font(.system(size: 34, weight: .medium, design: .rounded))
            .monospacedDigit()
            .accessibilityLabel("\(DurationFormatter.timer(duration)) remaining")
    }
}

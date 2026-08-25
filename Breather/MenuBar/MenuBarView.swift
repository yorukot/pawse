import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.locale) private var locale
    @State private var isSwitchModeHovered = false

    private var controller: SessionController { model.controller }

    private enum Layout {
        static let panelWidth: CGFloat = 320
        static let outerPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let contentSpacing: CGFloat = 12
        static let actionSpacing: CGFloat = 8
        static let controlHeight: CGFloat = 34
        static let controlCornerRadius: CGFloat = 8

        static var contentWidth: CGFloat {
            panelWidth - outerPadding * 2
        }
    }

    var body: some View {
        @Bindable var controller = controller

        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            stateContent
            upNextContent
            Divider()
            commonActions
        }
        .padding(Layout.outerPadding)
        .frame(width: Layout.panelWidth)
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
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            stateHeader(
                title: selectedMode.displayName,
                symbolName: selectedMode.symbolName,
                status: "Ready"
            )

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

            timerSection(controller.remainingTime)

            Button { controller.startSelectedMode() } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityLabel("Start \(selectedMode.displayName)")
        }
    }

    private func runningContent(_ session: RunningSession) -> some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            stateHeader(
                title: session.mode.displayName,
                symbolName: session.mode.symbolName,
                status: "In progress"
            )
            timerSection(controller.remainingTime, progress: controller.progress)

            if session.mode == .focus {
                HStack(spacing: Layout.actionSpacing) {
                    Button { controller.pauseFocus() } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button(role: .destructive) { controller.stopCurrentSession() } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }

                switchModeMenu
            } else {
                Text("Your break is active on every display.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func pausedContent(_ session: PausedSession) -> some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            stateHeader(
                title: session.mode.displayName,
                symbolName: "pause.circle",
                status: "Paused"
            )
            timerSection(controller.remainingTime, progress: controller.progress)

            HStack(spacing: Layout.actionSpacing) {
                Button { controller.resumeFocus() } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button(role: .destructive) { controller.stopCurrentSession() } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }

            switchModeMenu
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(session.mode.displayName) paused")
    }

    private func pendingContent(_ pending: PendingBreak) -> some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            stateHeader(
                title: pending.mode.displayName,
                symbolName: pending.mode.symbolName,
                status: "Ready"
            )
            timerSection(pending.plannedDuration)

            Text("Waiting for a natural stopping point…")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Layout.actionSpacing) {
                Button { controller.startPendingBreakNow() } label: {
                    Label("Start Break Now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button(role: .destructive) { controller.cancelPendingBreak() } label: {
                    Label("Cancel Break", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func enteringContent(_ entry: BreakEntry) -> some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            stateHeader(
                title: entry.mode.displayName,
                symbolName: entry.mode.symbolName,
                status: "Starting"
            )
            timerSection(controller.remainingTime, progress: controller.progress)

            Text("Resume using the keyboard or pointer now to defer this break.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var switchModeMenu: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: Layout.controlCornerRadius,
                style: .continuous
            )
            .fill(Color.primary.opacity(isSwitchModeHovered ? 0.16 : 0.10))
            .overlay {
                RoundedRectangle(
                    cornerRadius: Layout.controlCornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }

            Menu {
                Button("Short Break") { controller.requestModeSwitch(to: .shortBreak) }
                Button("Long Break") { controller.requestModeSwitch(to: .longBreak) }
            } label: {
                HStack {
                    Label("Switch Mode…", systemImage: "arrow.triangle.2.circlepath")
                    Spacer(minLength: Layout.actionSpacing)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(width: Layout.contentWidth, height: Layout.controlHeight)
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
        }
        .frame(width: Layout.contentWidth, height: Layout.controlHeight)
        .onHover { isSwitchModeHovered = $0 }
    }

    private var commonActions: some View {
        HStack(spacing: Layout.actionSpacing) {
            Button {
                openWindow(id: "breather")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Breather…", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button { NSApp.terminate(nil) } label: {
                Label("Quit Breather", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }

    private func timingLabel(_ timing: UpcomingBreakTiming) -> String {
        switch timing {
        case .readyNow:
            String(localized: "Ready now", locale: locale)
        case .inProgress:
            String(localized: "In progress", locale: locale)
        case .estimated(let duration):
            "≈ \(DurationFormatter.estimate(duration, locale: locale))"
        }
    }

    private var upNextContent: some View {
        let summary = controller.upcomingBreakSummary
        return GroupBox {
            VStack(alignment: .leading, spacing: Layout.actionSpacing) {
                detailRow(
                    title: "Short Break",
                    value: timingLabel(summary.shortBreak)
                )

                detailRow(
                    title: "Long Break",
                    value: timingLabel(summary.longBreak)
                )

                Text("Estimates exclude pauses and natural-break waiting.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        } label: {
            Label("Up Next", systemImage: "forward.end")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func stateHeader(title: String, symbolName: String, status: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.actionSpacing) {
            Label(title, systemImage: symbolName)
                .font(.headline)

            Spacer(minLength: Layout.actionSpacing)

            Text(status)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func timerSection(_ duration: TimeInterval, progress: Double? = nil) -> some View {
        VStack(spacing: 10) {
            timerText(duration)
                .frame(maxWidth: .infinity)

            if let progress {
                ProgressView(value: progress)
                    .tint(BreatherTheme.Colors.terracotta)
                    .accessibilityLabel("Session progress")
                    .accessibilityValue("\(Int(progress * 100)) percent")
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.contentSpacing) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func timerText(_ duration: TimeInterval) -> some View {
        Text(DurationFormatter.timer(duration))
            .font(.system(size: 42, weight: .medium, design: .rounded))
            .monospacedDigit()
            .accessibilityLabel("\(DurationFormatter.timer(duration)) remaining")
    }
}

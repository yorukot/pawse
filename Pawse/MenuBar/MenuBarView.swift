import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.locale) private var locale
    @State private var pendingConfirmation: PendingConfirmation?

    private var controller: SessionController { model.controller }

    private enum Layout {
        static let panelWidth: CGFloat = 320
        static let outerPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let contentSpacing: CGFloat = 12
        static let actionSpacing: CGFloat = 8
        static let actionLabelHeight: CGFloat = 20
        static let surfaceCornerRadius: CGFloat = 8
        static let bannerHeight: CGFloat = 44

        static var contentWidth: CGFloat {
            panelWidth - outerPadding * 2
        }
    }

    private enum PendingConfirmation: Equatable {
        case skipFocus
        case skipNextBreak
        case switchMode(SessionMode)

        var title: LocalizedStringResource {
            switch self {
            case .skipFocus: "Skip Focus?"
            case .skipNextBreak: "Skip Next Break?"
            case .switchMode: "Switch Mode?"
            }
        }

        var message: LocalizedStringResource {
            switch self {
            case .skipFocus:
                "The current Focus will be marked as skipped. Queued Focus sessions will be cleared, and the next Break will start immediately."
            case .skipNextBreak:
                "Adds one Focus duration to the timer."
            case .switchMode:
                "The current Focus session will be marked as interrupted."
            }
        }

        var confirmTitle: LocalizedStringResource {
            switch self {
            case .skipFocus: "Skip Focus"
            case .skipNextBreak: "Skip Next Break"
            case .switchMode: "Switch"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            miniBrandBanner
            stateContent
            upNextContent
            Divider()
            commonActions
        }
        .padding(Layout.outerPadding)
        .frame(width: Layout.panelWidth)
        .animation(.easeInOut(duration: 0.16), value: pendingConfirmation)
        .onAppear {
            controller.setMenuBarExtraPresented(true)
        }
        .onChange(of: controller.isFocusRunningOrPaused) { _, isFocusActive in
            if !isFocusActive {
                pendingConfirmation = nil
            }
        }
        .onDisappear {
            controller.setMenuBarExtraPresented(false)
            pendingConfirmation = nil
        }
    }

    private var miniBrandBanner: some View {
        ZStack(alignment: .leading) {
            Image("PawseMiniBanner")
                .resizable()
                .scaledToFill()
                .frame(width: Layout.contentWidth, height: Layout.bannerHeight)
                .clipped()

            HStack(spacing: 8) {
                Image("PawseLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)

                Text(verbatim: "Pawse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PawseTheme.Colors.ink)
            }
            .padding(.horizontal, 10)
        }
        .frame(width: Layout.contentWidth, height: Layout.bannerHeight)
        .clipShape(RoundedRectangle(
            cornerRadius: Layout.surfaceCornerRadius,
            style: .continuous
        ))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pawse")
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
                    Label {
                        Text(mode.displayName)
                    } icon: {
                        Image(systemName: mode.symbolName)
                    }
                    .tag(mode)
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
            .accessibilityLabel(
                Text("Start \(LocalizationText.string(selectedMode.displayName, locale: locale))")
            )
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

                focusSecondaryActions
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

            focusSecondaryActions
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            Text("\(LocalizationText.string(session.mode.displayName, locale: locale)) paused")
        )
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
        Menu {
            Button("Short Break") { requestConfirmation(.switchMode(.shortBreak)) }
            Button("Long Break") { requestConfirmation(.switchMode(.longBreak)) }
        } label: {
            Label("Switch Mode", systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private var skipNextBreakButton: some View {
        Button { requestConfirmation(.skipNextBreak) } label: {
            Label("Skip Next Break", systemImage: "forward.end.fill")
                .frame(maxWidth: .infinity, minHeight: Layout.actionLabelHeight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityHint("Adds one Focus duration to the timer.")
    }

    private var skipActions: some View {
        HStack(spacing: Layout.actionSpacing) {
            Button { requestConfirmation(.skipFocus) } label: {
                Label("Skip Focus", systemImage: "forward.fill")
                    .frame(maxWidth: .infinity, minHeight: Layout.actionLabelHeight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityHint("Ends the current Focus and immediately starts the next Break.")

            skipNextBreakButton
        }
    }

    @ViewBuilder
    private var focusSecondaryActions: some View {
        if let pendingConfirmation {
            inlineConfirmation(pendingConfirmation)
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            skipActions
            switchModeMenu
        }
    }

    private func inlineConfirmation(_ confirmation: PendingConfirmation) -> some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            Label {
                Text(confirmation.title)
            } icon: {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.headline)

            Text(confirmation.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Layout.actionSpacing) {
                Button("Cancel") {
                    pendingConfirmation = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button {
                    performConfirmation(confirmation)
                } label: {
                    Text(confirmation.confirmTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: Layout.surfaceCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Layout.surfaceCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func requestConfirmation(_ confirmation: PendingConfirmation) {
        pendingConfirmation = confirmation
    }

    private func performConfirmation(_ confirmation: PendingConfirmation) {
        pendingConfirmation = nil

        switch confirmation {
        case .skipFocus:
            controller.skipCurrentFocus()
        case .skipNextBreak:
            controller.skipNextBreak()
        case .switchMode(let mode):
            controller.switchMode(to: mode)
        }
    }

    private var commonActions: some View {
        HStack(spacing: Layout.actionSpacing) {
            Button {
                openWindow(id: "pawse")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Pawse", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button { NSApp.terminate(nil) } label: {
                Label("Quit Pawse", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
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

    private func stateHeader(
        title: LocalizedStringResource,
        symbolName: String,
        status: LocalizedStringResource
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.actionSpacing) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbolName)
            }
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
                    .tint(PawseTheme.Colors.pumpkin)
                    .accessibilityLabel("Session progress")
                    .accessibilityValue(
                        progress.formatted(.percent.precision(.fractionLength(0)).locale(locale))
                    )
            }
        }
    }

    private func detailRow(title: LocalizedStringResource, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.contentSpacing) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func timerText(_ duration: TimeInterval) -> some View {
        Text(DurationFormatter.timer(duration))
            .font(.system(size: 42, weight: .medium, design: .rounded))
            .monospacedDigit()
            .accessibilityLabel(
                Text("\(DurationFormatter.spoken(duration, locale: locale)) remaining")
            )
    }
}

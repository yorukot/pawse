import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case timers
    case cycle
    case breaks
    case sounds
    case appearance
    case general
    case privacy

    var id: Self { self }

    var title: String {
        switch self {
        case .timers: "Timers"
        case .cycle: "Cycle"
        case .breaks: "Break Behavior"
        case .sounds: "Sounds"
        case .appearance: "Appearance"
        case .general: "General"
        case .privacy: "Privacy"
        }
    }

    var symbolName: String {
        switch self {
        case .timers: "timer"
        case .cycle: "repeat"
        case .breaks: "hand.raised"
        case .sounds: "speaker.wave.2"
        case .appearance: "paintbrush"
        case .general: "gearshape"
        case .privacy: "lock.shield"
        }
    }
}

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var soundService: SoundService
    @Bindable var launchAtLoginService: LaunchAtLoginService
    @Bindable var analyticsStore: AnalyticsStore

    @State private var confirmsCycleReset = false
    @State private var confirmsSettingsReset = false
    @State private var confirmsAnalyticsClear = false
    @State private var selectedSection: SettingsSection? = .timers

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Breather")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            let section = selectedSection ?? .timers
            settingsContent(for: section)
                .navigationTitle(section.title)
        }
        .navigationSplitViewStyle(.balanced)
        .formStyle(.grouped)
        .frame(minWidth: 760, idealWidth: 820, minHeight: 520, idealHeight: 560)
        .confirmationDialog(
            "Reset Break Cycle?",
            isPresented: $confirmsCycleReset,
            titleVisibility: .visible
        ) {
            Button("Reset Break Cycle", role: .destructive) {
                settings.resetBreakCycle()
            }
        } message: {
            Text("Session history will not be changed.")
        }
        .confirmationDialog(
            "Reset Settings to Defaults?",
            isPresented: $confirmsSettingsReset,
            titleVisibility: .visible
        ) {
            Button("Reset Settings", role: .destructive) {
                settings.resetToDefaults()
                soundService.validateSelections()
                launchAtLoginService.setEnabled(false)
            }
        } message: {
            Text("Session history will not be deleted.")
        }
        .confirmationDialog(
            "Clear Analytics Data?",
            isPresented: $confirmsAnalyticsClear,
            titleVisibility: .visible
        ) {
            Button("Clear Analytics Data", role: .destructive) {
                analyticsStore.clear()
            }
        } message: {
            Text("Settings and the Focus cycle will not change.")
        }
    }

    @ViewBuilder
    private func settingsContent(for section: SettingsSection) -> some View {
        switch section {
        case .timers: timerSettings
        case .cycle: cycleSettings
        case .breaks: breakSettings
        case .sounds: soundSettings
        case .appearance: appearanceSettings
        case .general: generalSettings
        case .privacy: privacySettings
        }
    }

    private var timerSettings: some View {
        Form {
            Section("Timers") {
                Stepper("Focus: \(settings.focusMinutes) minutes", value: $settings.focusMinutes, in: 1...180)
                Stepper(
                    "Short Break: \(DurationFormatter.concise(TimeInterval(settings.shortBreakSeconds)))",
                    value: $settings.shortBreakSeconds,
                    in: 10...3_600,
                    step: 10
                )
                Stepper("Long Break: \(settings.longBreakMinutes) minutes", value: $settings.longBreakMinutes, in: 1...120)
            }
            Text("Changes apply to the next session and never move an active session’s deadline.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cycleSettings: some View {
        Form {
            Section("Focus and Break Cycle") {
                Stepper(
                    "Short Breaks Before Long Break: \(settings.shortBreaksBeforeLongBreak)",
                    value: $settings.shortBreaksBeforeLongBreak,
                    in: 1...12
                )
                Toggle("Automatically Start Breaks", isOn: $settings.automaticallyStartBreaks)
                Toggle("Automatically Start Next Focus", isOn: $settings.automaticallyStartNextFocus)
                LabeledContent("Completed Focus sessions in cycle", value: "\(settings.focusCycleCount)")
                Text("With the current setting, Breather schedules \(settings.shortBreaksBeforeLongBreak) Short Breaks before each Long Break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset Break Cycle…", role: .destructive) {
                    confirmsCycleReset = true
                }
            }
        }
    }

    private var breakSettings: some View {
        Form {
            Section("Break Behavior") {
                Toggle("Wait for Natural Break", isOn: $settings.waitForNaturalBreak)
                Text("When a Focus session ends, wait until you stop using the keyboard and mouse before starting the break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Idle Before Break", selection: $settings.idleBeforeBreak) {
                    ForEach([2.0, 3.0, 5.0, 10.0, 15.0, 30.0], id: \.self) { seconds in
                        Text("\(Int(seconds)) seconds").tag(seconds)
                    }
                }
                Stepper(
                    "Break Entry Grace Period: \(Int(settings.breakEntryGracePeriod)) seconds",
                    value: $settings.breakEntryGracePeriod,
                    in: 1...10,
                    step: 1
                )
                Text("Activity during the grace period returns Breather to Break Pending.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var soundSettings: some View {
        Form {
            Section("Sounds") {
                Toggle("Enable Sounds", isOn: $settings.enableSounds)
                Group {
                    soundPicker(
                        title: "Session Start Sound",
                        selection: $settings.sessionStartSound
                    )
                    soundPicker(
                        title: "Break Ready Sound",
                        selection: $settings.breakReadySound
                    )
                    soundPicker(
                        title: "Break Complete Sound",
                        selection: $settings.breakCompleteSound
                    )
                    LabeledContent("Volume") {
                        Slider(value: $settings.soundVolume, in: 0...1)
                            .frame(width: 220)
                            .accessibilityValue("\(Int(settings.soundVolume * 100)) percent")
                    }
                }
                .disabled(!settings.enableSounds)
            }
            Text("Only system sounds available on this Mac are shown.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSettings: some View {
        Form {
            Section("Appearance") {
                Toggle("Show Countdown During Break", isOn: $settings.showCountdownDuringBreak)
                Toggle("Show Session Progress in Menu Bar", isOn: $settings.showSessionProgressInMenuBar)
            }
            Text("Breather follows the system Reduce Motion and accessibility settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var generalSettings: some View {
        Form {
            Section("General") {
                LabeledContent("Starts on Launch", value: "Focus")
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLoginService.isEnabled },
                        set: { launchAtLoginService.setEnabled($0) }
                    )
                )
                if let errorMessage = launchAtLoginService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Reset Settings to Defaults…", role: .destructive) {
                    confirmsSettingsReset = true
                }
            }
        }
        .onAppear { launchAtLoginService.refresh() }
    }

    private var privacySettings: some View {
        Form {
            Section("Local and Private") {
                Text("Breather stores settings and session history locally on this Mac.")
                Text("Breather does not collect telemetry or send analytics to a server.")
            }
            Section("Natural Break") {
                Text("Breather checks how long the Mac has been idle so it can start breaks at a natural stopping point.")
                Text("Breather does not record which keys you press, where you move the pointer, what applications you use, or what is on your screen.")
            }
            Section("Session History") {
                Button("Clear Analytics Data…", role: .destructive) {
                    confirmsAnalyticsClear = true
                }
                .disabled(analyticsStore.records.isEmpty)
            }
        }
    }

    private func soundPicker(title: String, selection: Binding<String>) -> some View {
        LabeledContent(title) {
            HStack {
                Picker(title, selection: selection) {
                    ForEach(soundService.availableSounds) { sound in
                        Text(sound.name).tag(sound.name)
                    }
                }
                .labelsHidden()
                Button("Preview") {
                    let sound = soundService.availableSounds.first(where: { $0.name == selection.wrappedValue }) ?? .none
                    soundService.preview(sound)
                }
                .disabled(selection.wrappedValue == AppSound.none.name)
            }
        }
    }
}

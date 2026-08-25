import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var soundService: SoundService
    @Bindable var launchAtLoginService: LaunchAtLoginService

    @State private var confirmsCycleReset = false
    @State private var confirmsSettingsReset = false

    var body: some View {
        TabView {
            timerSettings
                .tabItem { Label("Timers", systemImage: "timer") }
            cycleSettings
                .tabItem { Label("Cycle", systemImage: "repeat") }
            breakSettings
                .tabItem { Label("Breaks", systemImage: "hand.raised") }
            soundSettings
                .tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
            appearanceSettings
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            generalSettings
                .tabItem { Label("General", systemImage: "gearshape") }
            privacySettings
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .formStyle(.grouped)
        .frame(width: 680, height: 500)
        .confirmationDialog(
            "Reset Focus Cycle?",
            isPresented: $confirmsCycleReset,
            titleVisibility: .visible
        ) {
            Button("Reset Focus Cycle", role: .destructive) {
                settings.resetFocusCycle()
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
                launchAtLoginService.setEnabled(false)
            }
        } message: {
            Text("Session history will not be deleted.")
        }
    }

    private var timerSettings: some View {
        Form {
            Section("Timers") {
                Stepper("Focus: \(settings.focusMinutes) minutes", value: $settings.focusMinutes, in: 1...180)
                Stepper("Short Break: \(settings.shortBreakMinutes) minutes", value: $settings.shortBreakMinutes, in: 1...60)
                Stepper("Long Break: \(settings.longBreakMinutes) minutes", value: $settings.longBreakMinutes, in: 1...120)
            }
            Text("Changes apply to the next session and never move an active session’s deadline.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cycleSettings: some View {
        Form {
            Section("Focus Cycle") {
                Stepper("Long Break Every: \(settings.longBreakEvery) Focus sessions", value: $settings.longBreakEvery, in: 2...12)
                Toggle("Automatically Start Breaks", isOn: $settings.automaticallyStartBreaks)
                Toggle("Automatically Start Next Focus", isOn: $settings.automaticallyStartNextFocus)
                LabeledContent("Completed Focus sessions in cycle", value: "\(settings.focusCycleCount)")
                Button("Reset Focus Cycle…", role: .destructive) {
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

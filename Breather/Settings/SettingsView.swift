import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            Form {
                Section("Timers") {
                    Stepper("Focus: \(settings.focusMinutes) minutes", value: $settings.focusMinutes, in: 1...180)
                    Stepper("Short Break: \(settings.shortBreakMinutes) minutes", value: $settings.shortBreakMinutes, in: 1...60)
                    Stepper("Long Break: \(settings.longBreakMinutes) minutes", value: $settings.longBreakMinutes, in: 1...120)
                }
            }
            .tabItem { Label("Timers", systemImage: "timer") }

            Form {
                Section("Cycle") {
                    Stepper("Long Break Every: \(settings.longBreakEvery) Focus sessions", value: $settings.longBreakEvery, in: 2...12)
                    Toggle("Automatically Start Breaks", isOn: $settings.automaticallyStartBreaks)
                    Toggle("Automatically Start Next Focus", isOn: $settings.automaticallyStartNextFocus)
                }
            }
            .tabItem { Label("Cycle", systemImage: "repeat") }

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
                }
            }
            .tabItem { Label("Breaks", systemImage: "hand.raised") }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 420)
    }
}

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
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 420)
    }
}

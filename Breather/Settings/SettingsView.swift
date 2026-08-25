import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Timers") {
                LabeledContent("Focus", value: "25 minutes")
                LabeledContent("Short Break", value: "5 minutes")
                LabeledContent("Long Break", value: "15 minutes")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 360)
        .navigationTitle("Breather Settings")
    }
}


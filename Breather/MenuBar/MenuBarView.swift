import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breather")
                .font(.headline)
            Text(model.statusText)
                .foregroundStyle(.secondary)

            Divider()

            Button("Analytics…") {
                openWindow(id: "analytics")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit Breather") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}


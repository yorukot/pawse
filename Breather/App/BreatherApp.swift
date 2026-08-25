import SwiftUI

@main
struct BreatherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Label("Breather", systemImage: "timer")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }

        Window("Analytics", id: "analytics") {
            AnalyticsView()
        }
        .defaultSize(width: 760, height: 560)
    }
}


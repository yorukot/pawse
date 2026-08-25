import SwiftUI

@main
struct BreatherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: model.settings)
        }

        Window("Analytics", id: "analytics") {
            AnalyticsView()
        }
        .defaultSize(width: 760, height: 560)
    }
}

import SwiftData
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
            SettingsView(
                settings: model.settings,
                soundService: model.soundService,
                launchAtLoginService: model.launchAtLoginService,
                analyticsStore: model.analyticsStore
            )
        }

        Window("Analytics", id: "analytics") {
            AnalyticsView(store: model.analyticsStore)
                .modelContainer(model.modelContainer)
        }
        .defaultSize(width: 760, height: 560)
    }
}

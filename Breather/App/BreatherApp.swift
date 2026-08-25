import AppKit
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

        Window("Breather", id: "breather") {
            BreatherWindowView(
                settings: model.settings,
                soundService: model.soundService,
                launchAtLoginService: model.launchAtLoginService,
                analyticsStore: model.analyticsStore,
                breakBackgroundService: model.breakBackgroundService,
                analyticsPersistenceNotice: model.analyticsPersistenceNotice
            )
            .modelContainer(model.modelContainer)
        }
        .defaultSize(width: 920, height: 650)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenBreatherCommand()
            }
        }
    }
}

private struct OpenBreatherCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Breather…") {
            openWindow(id: "breather")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

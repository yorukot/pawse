import AppKit
import SwiftData
import SwiftUI

@main
struct PawseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
                .environment(\.locale, model.languageStore.locale)
        } label: {
            MenuBarLabel(model: model)
                .environment(\.locale, model.languageStore.locale)
        }
        .menuBarExtraStyle(.window)

        Window("Pawse", id: "pawse") {
            PawseWindowView(
                settings: model.settings,
                soundService: model.soundService,
                launchAtLoginService: model.launchAtLoginService,
                analyticsStore: model.analyticsStore,
                breakBackgroundService: model.breakBackgroundService,
                languageStore: model.languageStore,
                appRestartService: model.appRestartService,
                sessionController: model.controller,
                analyticsPersistenceNotice: model.analyticsPersistenceNotice
            )
            .modelContainer(model.modelContainer)
            .environment(\.locale, model.languageStore.locale)
        }
        .defaultSize(width: 920, height: 650)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenPawseCommand()
                    .environment(\.locale, model.languageStore.locale)
            }
        }
    }
}

private struct OpenPawseCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Pawse") {
            openWindow(id: "pawse")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

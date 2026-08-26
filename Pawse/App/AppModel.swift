import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppModel {
    let settings: SettingsStore
    let controller: SessionController
    let analyticsStore: AnalyticsStore
    let modelContainer: ModelContainer
    let breakEnvironment: BreakEnvironmentCoordinator
    let breakPresentationState: BreakPresentationState
    let breakBackgroundService: BreakBackgroundService
    let soundService: SoundService
    let launchAtLoginService: LaunchAtLoginService
    let languageStore: AppLanguageStore
    let appRestartService: AppRestartService
    let analyticsPersistenceNotice: LocalizedStringResource?

    init(
        defaults: UserDefaults = .standard,
        modelContainer providedContainer: ModelContainer? = nil,
        startsFocusOnLaunch: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    ) {
        let languageStore = AppLanguageStore(defaults: defaults)
        let settings = SettingsStore(defaults: defaults)
        let container: ModelContainer
        var persistenceNotice: LocalizedStringResource?
        if let providedContainer {
            container = providedContainer
        } else {
            do {
                container = try ModelContainer(for: SessionRecord.self)
            } catch {
                do {
                    let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                    container = try ModelContainer(for: SessionRecord.self, configurations: fallback)
                    persistenceNotice = "Session history is temporarily in memory because local storage could not be opened."
                } catch {
                    fatalError("Pawse could not initialize session storage: \(error.localizedDescription)")
                }
            }
        }
        let analyticsStore = AnalyticsStore(modelContainer: container)
        let breakPresentationState = BreakPresentationState()
        let breakBackgroundService = BreakBackgroundService(settings: settings)
        let breakEnvironment = BreakEnvironmentCoordinator(
            settings: settings,
            backgroundProvider: breakBackgroundService,
            presentationState: breakPresentationState,
            locale: languageStore.locale
        )
        let soundService = SoundService(settings: settings)
        self.settings = settings
        self.analyticsStore = analyticsStore
        modelContainer = container
        self.breakEnvironment = breakEnvironment
        self.breakPresentationState = breakPresentationState
        self.breakBackgroundService = breakBackgroundService
        self.soundService = soundService
        self.languageStore = languageStore
        appRestartService = AppRestartService()
        launchAtLoginService = LaunchAtLoginService()
        analyticsPersistenceNotice = persistenceNotice
        let controller = SessionController(
            settings: settings,
            clock: SystemSessionClock(),
            scheduler: TaskRepeatingScheduler(),
            activityMonitor: SystemUserActivityMonitor(),
            soundPlayer: soundService,
            analyticsRecorder: analyticsStore,
            breakEnvironment: breakEnvironment
        )
        self.controller = controller
        breakEnvironment.connect(controller: controller)
        breakEnvironment.onStartBreak = { [weak controller] in
            controller?.startBreakFromReminder()
        }
        AppDelegate.sessionController = controller
        if startsFocusOnLaunch {
            controller.startFocusAtLaunch()
        }
    }
}

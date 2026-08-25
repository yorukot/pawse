import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let settings: SettingsStore
    let controller: SessionController
    let analyticsRecorder: InMemorySessionRecorder
    let breakEnvironment: BreakEnvironmentCoordinator
    let soundService: SoundService
    let launchAtLoginService: LaunchAtLoginService

    init(defaults: UserDefaults = .standard) {
        let settings = SettingsStore(defaults: defaults)
        let analyticsRecorder = InMemorySessionRecorder()
        let breakEnvironment = BreakEnvironmentCoordinator(settings: settings)
        let soundService = SoundService(settings: settings)
        self.settings = settings
        self.analyticsRecorder = analyticsRecorder
        self.breakEnvironment = breakEnvironment
        self.soundService = soundService
        launchAtLoginService = LaunchAtLoginService()
        let controller = SessionController(
            settings: settings,
            clock: SystemSessionClock(),
            scheduler: TaskRepeatingScheduler(),
            activityMonitor: SystemUserActivityMonitor(),
            soundPlayer: soundService,
            analyticsRecorder: analyticsRecorder,
            breakEnvironment: breakEnvironment
        )
        self.controller = controller
        breakEnvironment.connect(controller: controller)
        breakEnvironment.onStartBreak = { [weak controller] in
            controller?.startPendingBreakNow()
        }
        AppDelegate.sessionController = controller
    }
}

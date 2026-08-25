import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let settings: SettingsStore
    let controller: SessionController
    let analyticsRecorder: InMemorySessionRecorder

    init(defaults: UserDefaults = .standard) {
        let settings = SettingsStore(defaults: defaults)
        let analyticsRecorder = InMemorySessionRecorder()
        self.settings = settings
        self.analyticsRecorder = analyticsRecorder
        controller = SessionController(
            settings: settings,
            clock: SystemSessionClock(),
            scheduler: TaskRepeatingScheduler(),
            activityMonitor: DormantUserActivityMonitor(),
            soundPlayer: NoOpSoundPlayer(),
            analyticsRecorder: analyticsRecorder,
            breakEnvironment: NoOpBreakEnvironment()
        )
    }
}

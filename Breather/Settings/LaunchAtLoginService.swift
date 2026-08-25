import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginService {
    private(set) var isEnabled = false
    private(set) var errorMessage: LocalizedStringResource?

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "Launch at Login could not be changed: \(error.localizedDescription)"
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            errorMessage = "Allow Breather in System Settings → General → Login Items."
        }
    }
}

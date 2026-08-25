import AppKit

@MainActor
final class ScreenChangeMonitor: NSObject {
    var onChange: (@MainActor () -> Void)?
    private var isMonitoring = false

    func start() {
        guard !isMonitoring else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        isMonitoring = true
    }

    func stop() {
        guard isMonitoring else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        isMonitoring = false
    }

    @objc private func screenParametersChanged() {
        onChange?()
    }
}

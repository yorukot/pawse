import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sessionController: SessionController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.sessionController?.prepareForTermination()
    }
}

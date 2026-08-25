import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sessionController: SessionController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = makeApplicationIcon()
        NSApp.setActivationPolicy(.regular)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.sessionController?.prepareForTermination()
    }

    private func makeApplicationIcon() -> NSImage? {
        let icon = ZStack {
            RoundedRectangle(cornerRadius: 112, style: .continuous)
                .fill(Color(nsColor: .controlAccentColor))
            Image(systemName: "timer")
                .font(.system(size: 250, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 512, height: 512)

        let renderer = ImageRenderer(content: icon)
        renderer.scale = 2
        return renderer.nsImage
    }
}

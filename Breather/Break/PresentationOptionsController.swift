import AppKit

@MainActor
final class PresentationOptionsController {
    private(set) var savedOptions: NSApplication.PresentationOptions?

    var isApplied: Bool { savedOptions != nil }

    func applyForCommittedBreak() {
        guard savedOptions == nil else { return }
        let previous = NSApplication.shared.presentationOptions
        savedOptions = previous

        var breakOptions = previous
        breakOptions.remove([.autoHideDock, .autoHideMenuBar])
        breakOptions.formUnion([.hideDock, .hideMenuBar, .disableProcessSwitching])
        NSApplication.shared.presentationOptions = breakOptions
    }

    func restore() {
        guard let savedOptions else { return }
        NSApplication.shared.presentationOptions = savedOptions
        self.savedOptions = nil
    }
}

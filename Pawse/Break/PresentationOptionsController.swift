import AppKit

@MainActor
final class PresentationOptionsController {
    private(set) var savedOptions: NSApplication.PresentationOptions?

    var isApplied: Bool { savedOptions != nil }

    func applyForCommittedBreak() {
        captureOptionsIfNeeded()
        guard let savedOptions else { return }

        var breakOptions = savedOptions
        breakOptions.remove([.autoHideDock, .autoHideMenuBar])
        breakOptions.formUnion([.hideDock, .hideMenuBar, .disableProcessSwitching])
        NSApplication.shared.presentationOptions = breakOptions
    }

    func applyForDiscreetBreak() {
        captureOptionsIfNeeded()
        guard var discreetOptions = savedOptions else { return }
        // AppKit rejects process-switching suppression unless the Dock is
        // hidden or auto-hidden. Preserve the user's original option when it
        // already qualifies; otherwise use the least intrusive valid choice.
        if discreetOptions.isDisjoint(with: [.hideDock, .autoHideDock]) {
            discreetOptions.insert(.autoHideDock)
        }
        discreetOptions.insert(.disableProcessSwitching)
        NSApplication.shared.presentationOptions = discreetOptions
    }

    func restore() {
        guard let savedOptions else { return }
        NSApplication.shared.presentationOptions = savedOptions
        self.savedOptions = nil
    }

    private func captureOptionsIfNeeded() {
        guard savedOptions == nil else { return }
        savedOptions = NSApplication.shared.presentationOptions
    }
}

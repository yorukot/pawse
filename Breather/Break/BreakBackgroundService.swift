import AppKit
import CoreGraphics
import Foundation
import Observation

enum BreakBackgroundMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case systemWallpaper
    case customImage

    var id: Self { self }

    var displayName: String {
        switch self {
        case .systemWallpaper: "Desktop Wallpaper"
        case .customImage: "Custom Image"
        }
    }
}

@MainActor
protocol BreakBackgroundProviding: AnyObject {
    func image(for screen: NSScreen) -> NSImage?
    func resetCache()
}

@MainActor
@Observable
final class BreakBackgroundService: BreakBackgroundProviding {
    private let settings: SettingsStore
    private var wallpaperCache: [CGDirectDisplayID: NSImage] = [:]
    private var customImageCache: NSImage?

    private(set) var errorMessage: String?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func selectCustomImage(at url: URL) {
        errorMessage = nil
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            guard let image = Self.loadImage(at: url) else {
                throw BreakBackgroundError.invalidImage
            }
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: [.nameKey, .contentTypeKey],
                relativeTo: nil
            )
            settings.setCustomBreakImage(bookmark: bookmark, fileName: url.lastPathComponent)
            customImageCache = image
            wallpaperCache.removeAll()
        } catch {
            errorMessage = "Breather could not use that image. Choose a readable image file."
        }
    }

    func useSystemWallpaper() {
        settings.breakBackgroundMode = .systemWallpaper
        errorMessage = nil
        resetCache()
    }

    func removeCustomImage() {
        settings.clearCustomBreakImage()
        errorMessage = nil
        resetCache()
    }

    func image(for screen: NSScreen) -> NSImage? {
        errorMessage = nil
        switch settings.breakBackgroundMode {
        case .systemWallpaper:
            return wallpaperImage(for: screen)
        case .customImage:
            return customImage()
        }
    }

    func resetCache() {
        wallpaperCache.removeAll()
        customImageCache = nil
    }

    private func wallpaperImage(for screen: NSScreen) -> NSImage? {
        guard let displayID = Self.displayID(for: screen) else { return nil }
        if let cached = wallpaperCache[displayID] { return cached }
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = Self.loadImage(at: url) else {
            errorMessage = "The desktop wallpaper could not be loaded. Breaks will use a dark background."
            return nil
        }
        wallpaperCache[displayID] = image
        return image
    }

    private func customImage() -> NSImage? {
        if let customImageCache { return customImageCache }
        guard let bookmark = settings.customBreakImageBookmark else {
            errorMessage = "Choose a custom image before using this background."
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            guard let image = Self.loadImage(at: url) else {
                throw BreakBackgroundError.invalidImage
            }
            if isStale {
                let refreshedBookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: [.nameKey, .contentTypeKey],
                    relativeTo: nil
                )
                settings.setCustomBreakImage(bookmark: refreshedBookmark, fileName: url.lastPathComponent)
            }
            customImageCache = image
            return image
        } catch {
            errorMessage = "The selected break image is no longer available. Choose it again in Appearance."
            return nil
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    private static func loadImage(at url: URL) -> NSImage? {
        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data),
              image.isValid else { return nil }
        return image
    }
}

private enum BreakBackgroundError: Error {
    case invalidImage
}

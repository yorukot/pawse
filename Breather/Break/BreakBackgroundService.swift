import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

enum BreakBackgroundMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case systemWallpaper
    case customImage
    case solidColor

    var id: Self { self }

    var displayName: String {
        switch self {
        case .systemWallpaper: "Desktop Wallpaper"
        case .customImage: "Custom Image"
        case .solidColor: "Solid Color"
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
            let bookmark = try Self.readOnlyBookmark(for: url)
            settings.setCustomBreakImage(bookmark: bookmark, fileName: url.lastPathComponent)
            customImageCache = image
            wallpaperCache.removeAll()
        } catch {
            errorMessage = "Breather could not use or remember access to that image. Choose it again."
        }
    }

    func selectWallpaperFolder(at url: URL) {
        errorMessage = nil
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            guard Self.isDirectory(url) else {
                throw BreakBackgroundError.invalidFolder
            }
            let bookmark = try Self.readOnlyBookmark(for: url)
            settings.setSystemWallpaperFolder(
                bookmark: bookmark,
                folderName: url.lastPathComponent
            )
            resetCache()
        } catch {
            errorMessage = "Breather could not remember access to that folder. Choose it again."
        }
    }

    func useSystemWallpaper() {
        settings.breakBackgroundMode = .systemWallpaper
        errorMessage = nil
        resetCache()
    }

    func useSolidColor() {
        settings.breakBackgroundMode = .solidColor
        errorMessage = nil
        resetCache()
    }

    func removeCustomImage() {
        settings.clearCustomBreakImage()
        errorMessage = nil
        resetCache()
    }

    func removeWallpaperFolder() {
        settings.clearSystemWallpaperFolder()
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
        case .solidColor:
            return nil
        }
    }

    func resetCache() {
        wallpaperCache.removeAll()
        customImageCache = nil
    }

    private func wallpaperImage(for screen: NSScreen) -> NSImage? {
        guard let displayID = Self.displayID(for: screen) else { return nil }
        if let cached = wallpaperCache[displayID] { return cached }

        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            errorMessage = "macOS did not provide a desktop wallpaper. Breaks will use a dark background."
            return nil
        }

        if let image = Self.loadImage(at: url) {
            wallpaperCache[displayID] = image
            return image
        }

        guard let bookmark = settings.systemWallpaperFolderBookmark else {
            errorMessage = Self.wallpaperFailureMessage(for: url, hasFolderAccess: false)
            return nil
        }

        let resolvedFolder: ResolvedBookmark
        do {
            resolvedFolder = try Self.resolveScopedBookmark(bookmark)
        } catch {
            errorMessage = "Wallpaper folder access is no longer available. Choose the folder again in Appearance."
            return nil
        }

        let hasAccess = resolvedFolder.url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { resolvedFolder.url.stopAccessingSecurityScopedResource() }
        }

        guard Self.isDescendant(url, of: resolvedFolder.url) else {
            errorMessage = "The current wallpaper is outside the authorized folder. Change Wallpaper Folder in Appearance."
            return nil
        }

        guard let image = Self.loadImage(at: url) else {
            errorMessage = Self.wallpaperFailureMessage(for: url, hasFolderAccess: true)
            return nil
        }

        if resolvedFolder.isStale {
            do {
                let refreshedBookmark = try Self.readOnlyBookmark(for: resolvedFolder.url)
                settings.setSystemWallpaperFolder(
                    bookmark: refreshedBookmark,
                    folderName: resolvedFolder.url.lastPathComponent
                )
            } catch {
                errorMessage = "Wallpaper folder access could not be refreshed. Choose the folder again in Appearance."
                return nil
            }
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

        let resolved: ResolvedBookmark
        do {
            resolved = try Self.resolveScopedBookmark(bookmark)
        } catch {
            return migrateLegacyCustomImage(bookmark)
        }

        let hasAccess = resolved.url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { resolved.url.stopAccessingSecurityScopedResource() }
        }

        guard let image = Self.loadImage(at: resolved.url) else {
            errorMessage = "The selected break image is no longer available. Choose it again in Appearance."
            return nil
        }

        if resolved.isStale {
            do {
                let refreshedBookmark = try Self.readOnlyBookmark(for: resolved.url)
                settings.setCustomBreakImage(
                    bookmark: refreshedBookmark,
                    fileName: resolved.url.lastPathComponent
                )
            } catch {
                errorMessage = "Access to the selected break image could not be refreshed. Choose it again in Appearance."
                return nil
            }
        }

        customImageCache = image
        return image
    }

    private func migrateLegacyCustomImage(_ bookmark: Data) -> NSImage? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
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
            let migratedBookmark = try Self.readOnlyBookmark(for: url)
            settings.setCustomBreakImage(
                bookmark: migratedBookmark,
                fileName: url.lastPathComponent
            )
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

    private static func readOnlyBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: [.nameKey],
            relativeTo: nil
        )
    }

    private static func resolveScopedBookmark(_ bookmark: Data) throws -> ResolvedBookmark {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return ResolvedBookmark(url: url, isStale: isStale)
    }

    private static func loadImage(at url: URL) -> NSImage? {
        // On some macOS releases (and for dynamic wallpapers), NSWorkspace
        // returns the wallpaper package/directory rather than one image file.
        // Resolve that directory to a readable image before constructing the
        // NSImage. The old implementation attempted Data(contentsOf:) on the
        // directory and consequently always fell back to a black background.
        let candidateURLs: [URL]
        if Self.isDirectory(url) {
            let fileManager = FileManager.default
            candidateURLs = (fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
            )?.compactMap { item in
                guard let itemURL = item as? URL,
                      !Self.isDirectory(itemURL),
                      Self.isImageFile(itemURL) else { return nil }
                return itemURL
            } ?? []).sorted { $0.path < $1.path }
        } else {
            candidateURLs = [url]
        }

        for candidateURL in candidateURLs {
            guard let data = try? Data(contentsOf: candidateURL) else { continue }

            // Decode into an in-memory CGImage while any security scope is
            // active. An NSImage initialized from a file URL may read lazily
            // after the scope has already been released.
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )
            }

            if let image = NSImage(data: data), image.isValid {
                return image
            }
        }
        return nil
    }

    private static func isDescendant(_ candidate: URL, of folder: URL) -> Bool {
        let candidateComponents = candidate.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let folderComponents = folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return candidateComponents.starts(with: folderComponents)
    }

    private static func wallpaperFailureMessage(for url: URL, hasFolderAccess: Bool) -> String {
        if ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased()) {
            return "Video-only desktop wallpapers are not supported. Breaks will use a dark background."
        }
        if hasFolderAccess {
            return "The desktop wallpaper could not be loaded as an image. Breaks will use a dark background."
        }
        return "Breather needs access to the folder containing this wallpaper. Choose Wallpaper Folder in Appearance."
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var directory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
            && directory.boolValue
    }

    private static func isImageFile(_ url: URL) -> Bool {
        if let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType,
           type.conforms(to: .image) {
            return true
        }
        return ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "webp"].contains(
            url.pathExtension.lowercased()
        )
    }
}

private enum BreakBackgroundError: Error {
    case invalidImage
    case invalidFolder
}

private struct ResolvedBookmark {
    let url: URL
    let isStale: Bool
}

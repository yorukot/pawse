import AppKit
import Foundation
import XCTest
@testable import Breather

@MainActor
final class BreakBackgroundServiceTests: XCTestCase {
    func testCustomImageUsesReloadableReadOnlySecurityScopedBookmark() throws {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PawseBackgroundTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let imageURL = folderURL.appendingPathComponent("Rest.png")
        try XCTUnwrap(Data(base64Encoded: Self.onePixelPNG)).write(to: imageURL)

        let settings = SettingsStore(defaults: defaults)
        let service = BreakBackgroundService(settings: settings)
        service.selectCustomImage(at: imageURL)

        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(settings.breakBackgroundMode, .customImage)
        XCTAssertEqual(settings.customBreakImageName, "Rest.png")

        let bookmark = try XCTUnwrap(settings.customBreakImageBookmark)
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        XCTAssertEqual(resolvedURL.standardizedFileURL, imageURL.standardizedFileURL)
        XCTAssertFalse(isStale)

        service.resetCache()
        let screen = try XCTUnwrap(NSScreen.screens.first)
        let reloadedImage = service.image(for: screen)
        XCTAssertNotNil(reloadedImage)
        XCTAssertNil(service.errorMessage)
    }

    func testSolidColorReturnsNoImageWithoutAnError() throws {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        let service = BreakBackgroundService(settings: settings)
        service.useSolidColor()

        let screen = try XCTUnwrap(NSScreen.screens.first)
        XCTAssertNil(service.image(for: screen))
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(settings.breakBackgroundMode, .solidColor)
    }

    func testWallpaperFolderUsesReloadableReadOnlySecurityScopedBookmark() throws {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PawseWallpaperTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let settings = SettingsStore(defaults: defaults)
        let service = BreakBackgroundService(settings: settings)
        service.selectWallpaperFolder(at: folderURL)

        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(settings.breakBackgroundMode, .systemWallpaper)
        XCTAssertEqual(settings.systemWallpaperFolderName, folderURL.lastPathComponent)

        let bookmark = try XCTUnwrap(settings.systemWallpaperFolderBookmark)
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        XCTAssertEqual(resolvedURL.standardizedFileURL, folderURL.standardizedFileURL)
        XCTAssertFalse(isStale)

        service.removeWallpaperFolder()
        XCTAssertNil(settings.systemWallpaperFolderBookmark)
        XCTAssertNil(settings.systemWallpaperFolderName)
        XCTAssertEqual(settings.breakBackgroundMode, .systemWallpaper)
    }

    private static let onePixelPNG =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "PawseBackgroundTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

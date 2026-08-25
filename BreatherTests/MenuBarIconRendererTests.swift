import AppKit
import SwiftUI
import XCTest
@testable import Breather

@MainActor
final class MenuBarIconRendererTests: XCTestCase {
    func testRendererProducesAMonochromeImageAtMenuBarSize() throws {
        let image = try renderedImage(fractionRemaining: 1, showsRing: true)

        XCTAssertEqual(image.size.width, MenuBarIconRenderer.iconSize)
        XCTAssertEqual(image.size.height, MenuBarIconRenderer.iconSize)
        XCTAssertFalse(image.isTemplate)
        XCTAssertEqual(chromaticPixelCount(in: image), 0)
    }

    func testCountdownArcShrinksWithTheRemainingFraction() throws {
        let full = try renderedImage(fractionRemaining: 1, showsRing: true)
        let half = try renderedImage(fractionRemaining: 0.5, showsRing: true)
        let empty = try renderedImage(fractionRemaining: 0, showsRing: true)

        let fullSolidPixels = solidPixelCount(in: full)
        let halfSolidPixels = solidPixelCount(in: half)
        let emptySolidPixels = solidPixelCount(in: empty)

        XCTAssertGreaterThan(fullSolidPixels, halfSolidPixels)
        XCTAssertGreaterThan(halfSolidPixels, emptySolidPixels)
        XCTAssertEqual(chromaticPixelCount(in: full), 0)
        XCTAssertEqual(chromaticPixelCount(in: half), 0)
    }

    func testInactiveStateKeepsOnlyTheNeutralTrack() throws {
        let inactive = try renderedImage(fractionRemaining: nil, showsRing: true)
        let ringDisabled = try renderedImage(fractionRemaining: nil, showsRing: false)

        XCTAssertEqual(chromaticPixelCount(in: inactive), 0)
        XCTAssertGreaterThan(
            visiblePixelCount(in: inactive),
            visiblePixelCount(in: ringDisabled),
            "The inactive icon should retain a visible track around the center symbol."
        )
    }

    func testTimerAndSleepingCatProduceDistinctVisibleMarks() throws {
        let timer = try renderedImage(
            iconStyle: .timer,
            fractionRemaining: nil,
            showsRing: false
        )
        let sleepingCat = try renderedImage(
            iconStyle: .sleepingCat,
            fractionRemaining: nil,
            showsRing: false
        )

        XCTAssertGreaterThan(visiblePixelCount(in: sleepingCat), 0)
        XCTAssertGreaterThan(pixelDifferenceCount(timer, sleepingCat), 20)
        XCTAssertEqual(chromaticPixelCount(in: sleepingCat), 0)
    }

    private func renderedImage(
        iconStyle: MenuBarIconStyle = .timer,
        fractionRemaining: Double?,
        showsRing: Bool
    ) throws -> NSImage {
        try XCTUnwrap(
            MenuBarIconRenderer.image(
                iconStyle: iconStyle,
                symbolName: "timer",
                fractionRemaining: fractionRemaining,
                showsRing: showsRing,
                colorScheme: .dark,
                scale: 2
            )
        )
    }

    private func chromaticPixelCount(in image: NSImage) -> Int {
        pixels(in: image).count { color in
            guard color.alphaComponent > 0.2 else { return false }
            let components = [color.redComponent, color.greenComponent, color.blueComponent]
            return (components.max() ?? 0) - (components.min() ?? 0) > 0.04
        }
    }

    private func solidPixelCount(in image: NSImage) -> Int {
        pixels(in: image).count { $0.alphaComponent > 0.65 }
    }

    private func visiblePixelCount(in image: NSImage) -> Int {
        pixels(in: image).count { $0.alphaComponent > 0.1 }
    }

    private func pixelDifferenceCount(_ first: NSImage, _ second: NSImage) -> Int {
        zip(pixels(in: first), pixels(in: second)).count { pair in
            let (firstColor, secondColor) = pair
            return abs(firstColor.alphaComponent - secondColor.alphaComponent) > 0.1
        }
    }

    private func pixels(in image: NSImage) -> [NSColor] {
        guard
            let data = image.tiffRepresentation,
            let representation = NSBitmapImageRep(data: data)
        else {
            return []
        }

        return (0 ..< representation.pixelsHigh).flatMap { y in
            (0 ..< representation.pixelsWide).compactMap { x in
                representation.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
            }
        }
    }
}

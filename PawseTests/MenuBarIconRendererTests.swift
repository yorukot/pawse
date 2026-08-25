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

    func testCountdownDirectionControlsWhichSideDrains() throws {
        let clockwise = try renderedImage(
            fractionRemaining: 0.75,
            showsRing: true,
            ringDirection: .clockwise
        )
        let counterclockwise = try renderedImage(
            fractionRemaining: 0.75,
            showsRing: true,
            ringDirection: .counterclockwise
        )

        let clockwiseCounts = solidRingPixelCounts(in: clockwise)
        let counterclockwiseCounts = solidRingPixelCounts(in: counterclockwise)

        XCTAssertGreaterThan(clockwiseCounts.left, clockwiseCounts.right)
        XCTAssertGreaterThan(counterclockwiseCounts.right, counterclockwiseCounts.left)
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

    func testTimerAndSleepingDogProduceDistinctVisibleMarks() throws {
        let timer = try renderedImage(
            iconStyle: .timer,
            fractionRemaining: nil,
            showsRing: false
        )
        let sleepingDog = try renderedImage(
            iconStyle: .sleepingDog,
            fractionRemaining: nil,
            showsRing: false
        )

        XCTAssertGreaterThan(visiblePixelCount(in: sleepingDog), 0)
        XCTAssertGreaterThan(pixelDifferenceCount(timer, sleepingDog), 20)
        XCTAssertEqual(chromaticPixelCount(in: sleepingDog), 0)
    }

    func testRendererReusesIndistinguishableFractionSteps() throws {
        let first = try renderedImage(fractionRemaining: 0.5001, showsRing: true)
        let second = try renderedImage(fractionRemaining: 0.5002, showsRing: true)

        XCTAssertTrue(first === second)
    }

    private func renderedImage(
        iconStyle: MenuBarIconStyle = .timer,
        fractionRemaining: Double?,
        showsRing: Bool,
        ringDirection: MenuBarRingDirection = .clockwise
    ) throws -> NSImage {
        try XCTUnwrap(
            MenuBarIconRenderer.image(
                iconStyle: iconStyle,
                symbolName: "timer",
                fractionRemaining: fractionRemaining,
                showsRing: showsRing,
                ringDirection: ringDirection,
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

    private func solidRingPixelCounts(in image: NSImage) -> (left: Int, right: Int) {
        guard
            let data = image.tiffRepresentation,
            let representation = NSBitmapImageRep(data: data)
        else {
            return (0, 0)
        }

        let centerX = Double(representation.pixelsWide - 1) / 2
        let centerY = Double(representation.pixelsHigh - 1) / 2
        let minimumRadius = Double(representation.pixelsWide) * 0.32
        var left = 0
        var right = 0

        for y in 0 ..< representation.pixelsHigh {
            for x in 0 ..< representation.pixelsWide {
                let horizontalOffset = Double(x) - centerX
                let verticalOffset = Double(y) - centerY
                let radius = hypot(horizontalOffset, verticalOffset)
                guard radius >= minimumRadius,
                      let color = representation.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.65 else {
                    continue
                }

                if horizontalOffset < 0 {
                    left += 1
                } else if horizontalOffset > 0 {
                    right += 1
                }
            }
        }

        return (left, right)
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

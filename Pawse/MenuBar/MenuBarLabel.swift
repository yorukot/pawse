import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    var body: some View {
        let controller = model.controller
        let isDiscreet = model.breakPresentationState.isDiscreet
        CountdownRingIcon(
            iconStyle: model.settings.menuBarIconStyle,
            symbolName: controller.currentMode.symbolName,
            fractionRemaining: controller.countdownFractionRemaining,
            showsRing: isDiscreet
                ? model.settings.showDiscreetBreakRing
                : model.settings.showSessionProgressInMenuBar,
            ringDirection: model.settings.menuBarRingDirection,
            ringAppearance: isDiscreet ? .discreet : .standard,
            colorScheme: colorScheme
        )
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let controller = model.controller
        let modeName = LocalizationText.string(controller.currentMode.displayName, locale: locale)
        let remaining = DurationFormatter.spoken(controller.remainingTime, locale: locale)
        if model.breakPresentationState.isDiscreet {
            return String(
                localized: "Pawse, discreet \(modeName), \(remaining) remaining",
                locale: locale
            )
        }
        if case .running = controller.state {
            return String(localized: "Pawse, \(modeName), \(remaining) remaining", locale: locale)
        }
        if case .paused = controller.state {
            return String(localized: "Pawse, Focus paused, \(remaining) remaining", locale: locale)
        }
        if case .breakPending = controller.state {
            return String(localized: "Pawse, \(modeName) ready", locale: locale)
        }
        return String(localized: "Pawse, \(modeName)", locale: locale)
    }
}

private struct CountdownRingIcon: View {
    let iconStyle: MenuBarIconStyle
    let symbolName: String
    let fractionRemaining: Double?
    let showsRing: Bool
    let ringDirection: MenuBarRingDirection
    let ringAppearance: MenuBarRingAppearance
    let colorScheme: ColorScheme

    var body: some View {
        Group {
            if let image = MenuBarIconRenderer.image(
                iconStyle: iconStyle,
                symbolName: symbolName,
                fractionRemaining: fractionRemaining,
                showsRing: showsRing,
                ringDirection: ringDirection,
                colorScheme: colorScheme,
                ringAppearance: ringAppearance
            ) {
                Image(nsImage: image)
                    .renderingMode(.original)
            } else {
                // Preserve a usable menu bar item if off-screen rendering ever
                // fails on a future macOS release.
                fallbackMark
            }
        }
        .frame(width: MenuBarIconRenderer.iconSize, height: MenuBarIconRenderer.iconSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fallbackMark: some View {
        switch iconStyle {
        case .timer:
            Image(systemName: symbolName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        case .sleepingDog:
            Image("MenuBarSleepingDog")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: MenuBarIconRenderer.centerMarkSize, height: MenuBarIconRenderer.centerMarkSize)
                .foregroundStyle(.primary)
        }
    }
}

@MainActor
enum MenuBarIconRenderer {
    static let iconSize: CGFloat = 22
    static let centerMarkSize: CGFloat = 13

    // At this size the ring has fewer than 120 visually distinct positions.
    // Reusing those tiny bitmaps avoids rebuilding graphics resources every
    // second throughout a Focus session.
    private static let fractionStepCount = 120
    private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 16
        cache.totalCostLimit = 512 * 1024
        return cache
    }()

    static func image(
        iconStyle: MenuBarIconStyle,
        symbolName: String,
        fractionRemaining: Double?,
        showsRing: Bool,
        ringDirection: MenuBarRingDirection,
        colorScheme: ColorScheme,
        ringAppearance: MenuBarRingAppearance = .standard,
        scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    ) -> NSImage? {
        let clampedScale = max(1, scale)
        let fractionStep = fractionRemaining.map {
            Int((min(1, max(0, $0)) * Double(fractionStepCount)).rounded())
        }
        let cacheKey = NSString(string: [
            iconStyle.rawValue,
            symbolName,
            fractionStep.map(String.init) ?? "inactive",
            showsRing ? "ring" : "mark",
            ringDirection.rawValue,
            ringAppearance.rawValue,
            colorScheme == .dark ? "dark" : "light",
            String(Int((clampedScale * 100).rounded()))
        ].joined(separator: ":"))

        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let representation = bitmapRepresentation(scale: clampedScale),
              let graphicsContext = NSGraphicsContext(bitmapImageRep: representation) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high
        graphicsContext.cgContext.clear(CGRect(
            x: 0,
            y: 0,
            width: representation.pixelsWide,
            height: representation.pixelsHigh
        ))
        graphicsContext.cgContext.scaleBy(x: clampedScale, y: clampedScale)

        let foregroundColor: NSColor = colorScheme == .dark ? .white : .black
        let ringColor: NSColor = switch ringAppearance {
        case .standard:
            foregroundColor
        case .discreet:
            discreetRingColor(for: colorScheme)
        }
        drawCenterMark(
            iconStyle: iconStyle,
            symbolName: symbolName,
            foregroundColor: foregroundColor
        )
        if showsRing {
            drawRing(
                fraction: fractionStep.map { Double($0) / Double(fractionStepCount) },
                direction: ringDirection,
                foregroundColor: ringColor
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        representation.size = NSSize(width: iconSize, height: iconSize)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        image.isTemplate = false
        imageCache.setObject(
            image,
            forKey: cacheKey,
            cost: representation.pixelsWide * representation.pixelsHigh * 4
        )
        return image
    }

    private static func discreetRingColor(for colorScheme: ColorScheme) -> NSColor {
        switch colorScheme {
        case .dark:
            NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.08, alpha: 1)
        case .light:
            NSColor(calibratedRed: 0.72, green: 0.45, blue: 0.00, alpha: 1)
        @unknown default:
            NSColor.systemYellow
        }
    }

    private static func bitmapRepresentation(scale: CGFloat) -> NSBitmapImageRep? {
        let pixelSize = Int((iconSize * scale).rounded(.up))
        return NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    }

    private static func drawCenterMark(
        iconStyle: MenuBarIconStyle,
        symbolName: String,
        foregroundColor: NSColor
    ) {
        let image: NSImage?
        let maximumSize: CGFloat
        switch iconStyle {
        case .timer:
            let configuration = NSImage.SymbolConfiguration(pointSize: 8.5, weight: .bold)
            image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(configuration)
            maximumSize = 10
        case .sleepingDog:
            image = NSImage(named: "MenuBarSleepingDog")
            maximumSize = centerMarkSize
        }

        guard let image else { return }
        let sourceSize = image.size
        let sourceAspectRatio = sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1
        let targetSize: NSSize
        if sourceAspectRatio > 1 {
            targetSize = NSSize(width: maximumSize, height: maximumSize / sourceAspectRatio)
        } else {
            targetSize = NSSize(width: maximumSize * sourceAspectRatio, height: maximumSize)
        }
        let targetRect = NSRect(
            x: (iconSize - targetSize.width) / 2,
            y: (iconSize - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        )

        image.draw(
            in: targetRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        // Asset-catalog template tinting normally happens in NSImageView.
        // Source-atop applies the same monochrome tint to this bitmap without
        // introducing an AppKit view or a SwiftUI render graph.
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        context.setFillColor(foregroundColor.cgColor)
        context.fill(targetRect)
        context.restoreGState()
    }

    private static func drawRing(
        fraction: Double?,
        direction: MenuBarRingDirection,
        foregroundColor: NSColor
    ) {
        let center = NSPoint(x: iconSize / 2, y: iconSize / 2)
        let radius = (iconSize - 3.2) / 2

        let track = NSBezierPath()
        track.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        track.lineWidth = 2
        track.lineCapStyle = .round
        foregroundColor.withAlphaComponent(0.28).setStroke()
        track.stroke()

        guard let fraction, fraction > 0 else { return }
        let active = NSBezierPath()
        switch direction {
        case .clockwise:
            active.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90,
                endAngle: 90 + 360 * fraction,
                clockwise: false
            )
        case .counterclockwise:
            active.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90 + 360 * (1 - fraction),
                endAngle: 450,
                clockwise: false
            )
        }
        active.lineWidth = 2.2
        active.lineCapStyle = .round
        foregroundColor.setStroke()
        active.stroke()
    }
}

import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let controller = model.controller
        CountdownRingIcon(
            iconStyle: model.settings.menuBarIconStyle,
            symbolName: controller.currentMode.symbolName,
            fractionRemaining: controller.countdownFractionRemaining,
            showsRing: model.settings.showSessionProgressInMenuBar,
            colorScheme: colorScheme
        )
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let controller = model.controller
        if case .running = controller.state {
            return "Breather, \(controller.currentMode.displayName), \(DurationFormatter.timer(controller.remainingTime)) remaining"
        }
        if case .paused = controller.state {
            return "Breather, Focus paused, \(DurationFormatter.timer(controller.remainingTime)) remaining"
        }
        if case .breakPending = controller.state {
            return "Breather, \(controller.currentMode.displayName) ready"
        }
        return "Breather, \(controller.currentMode.displayName)"
    }
}

private struct CountdownRingIcon: View {
    let iconStyle: MenuBarIconStyle
    let symbolName: String
    let fractionRemaining: Double?
    let showsRing: Bool
    let colorScheme: ColorScheme

    var body: some View {
        Group {
            if let image = MenuBarIconRenderer.image(
                iconStyle: iconStyle,
                symbolName: symbolName,
                fractionRemaining: fractionRemaining,
                showsRing: showsRing,
                colorScheme: colorScheme
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
        case .sleepingCat:
            Image("MenuBarSleepingCat")
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

    static func image(
        iconStyle: MenuBarIconStyle,
        symbolName: String,
        fractionRemaining: Double?,
        showsRing: Bool,
        colorScheme: ColorScheme,
        scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    ) -> NSImage? {
        let artwork = MenuBarIconArtwork(
            iconStyle: iconStyle,
            symbolName: symbolName,
            fractionRemaining: fractionRemaining,
            showsRing: showsRing,
            colorScheme: colorScheme
        )
        let renderer = ImageRenderer(content: artwork)
        renderer.proposedSize = ProposedViewSize(width: iconSize, height: iconSize)
        renderer.scale = scale

        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}

private struct MenuBarIconArtwork: View {
    let iconStyle: MenuBarIconStyle
    let symbolName: String
    let fractionRemaining: Double?
    let showsRing: Bool
    let colorScheme: ColorScheme

    private var foregroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var clampedFractionRemaining: Double? {
        fractionRemaining.map { min(1, max(0, $0)) }
    }

    var body: some View {
        ZStack {
            if showsRing {
                Circle()
                    .stroke(
                        foregroundColor.opacity(0.28),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .padding(1.6)

                if let fraction = clampedFractionRemaining, fraction > 0 {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            foregroundColor,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                        )
                        .padding(1.6)
                        .rotationEffect(.degrees(-90))
                }
            }

            centerMark
        }
        .frame(width: MenuBarIconRenderer.iconSize, height: MenuBarIconRenderer.iconSize)
    }

    @ViewBuilder
    private var centerMark: some View {
        switch iconStyle {
        case .timer:
            Image(systemName: symbolName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(foregroundColor)
        case .sleepingCat:
            Image("MenuBarSleepingCat")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: MenuBarIconRenderer.centerMarkSize, height: MenuBarIconRenderer.centerMarkSize)
                .foregroundStyle(foregroundColor)
        }
    }
}

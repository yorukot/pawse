import Foundation

enum DurationFormatter {
    static func timer(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(ceil(duration)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func concise(
        _ duration: TimeInterval,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        formattedUnits(
            duration.rounded(),
            allowedUnits: [.minutes, .seconds],
            width: .abbreviated,
            locale: locale
        )
    }

    static func estimate(
        _ duration: TimeInterval,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        formattedUnits(
            ceil(duration),
            allowedUnits: [.hours, .minutes, .seconds],
            width: .abbreviated,
            locale: locale
        )
    }

    static func analytics(
        _ duration: TimeInterval,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        formattedUnits(
            duration,
            allowedUnits: [.hours, .minutes],
            width: .abbreviated,
            locale: locale
        )
    }

    static func spoken(
        _ duration: TimeInterval,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        formattedUnits(
            duration,
            allowedUnits: [.hours, .minutes, .seconds],
            width: .wide,
            locale: locale
        )
    }

    private static func formattedUnits(
        _ duration: TimeInterval,
        allowedUnits: Set<Duration.UnitsFormatStyle.Unit>,
        width: Duration.UnitsFormatStyle.UnitWidth,
        locale: Locale
    ) -> String {
        Duration.seconds(max(0, duration)).formatted(
            .units(
                allowed: allowedUnits,
                width: width,
                maximumUnitCount: 2,
                zeroValueUnits: .hide
            )
            .locale(locale)
        )
    }
}

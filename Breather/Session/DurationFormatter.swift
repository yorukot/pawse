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

    static func concise(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        return "\(minutes) min"
    }
}

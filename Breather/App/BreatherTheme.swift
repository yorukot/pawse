import SwiftUI

enum BreatherTheme {
    enum Colors {
        static let ink = Color(red: 0.06, green: 0.10, blue: 0.32)
        static let cream = Color(red: 1.00, green: 0.94, blue: 0.86)
        static let terracotta = Color(red: 0.85, green: 0.44, blue: 0.29)
        static let coral = Color(red: 0.95, green: 0.55, blue: 0.47)
        static let lavender = Color(red: 0.65, green: 0.58, blue: 0.68)
    }

    enum Metrics {
        static let brandBannerCornerRadius: CGFloat = 12
        static let reminderCornerRadius: CGFloat = 16
        static let reminderLogoSize: CGFloat = 44
        static let sidebarLogoSize: CGFloat = 44
        static let sidebarMinimumWidth: CGFloat = 220
        static let sidebarIdealWidth: CGFloat = 240
        static let sidebarMaximumWidth: CGFloat = 280
    }
}

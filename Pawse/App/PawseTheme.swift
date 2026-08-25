import SwiftUI

enum PawseTheme {
    enum Colors {
        static let ink = Color(red: 0.05, green: 0.17, blue: 0.43)
        static let cream = Color(red: 1.00, green: 0.96, blue: 0.89)
        static let pumpkin = Color(red: 1.00, green: 0.48, blue: 0.09)
        static let lake = Color(red: 0.38, green: 0.81, blue: 0.84)
        static let mountain = Color(red: 0.61, green: 0.79, blue: 0.85)
    }

    enum Metrics {
        static let brandBannerCornerRadius: CGFloat = 12
        static let reminderCornerRadius: CGFloat = 16
        static let reminderMascotWidth: CGFloat = 44
        static let reminderMascotHeight: CGFloat = 44
        static let sidebarLogoSize: CGFloat = 38
        static let sidebarMinimumWidth: CGFloat = 176
        static let sidebarIdealWidth: CGFloat = 192
        static let sidebarMaximumWidth: CGFloat = 220
    }
}

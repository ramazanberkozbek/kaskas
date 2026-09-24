import SwiftUI

enum Theme {
    enum Typography {
        static let status = Font.system(.headline, design: .rounded, weight: .semibold)
        static let reminderTitle = Font.system(.title3, design: .rounded, weight: .semibold)
        static let breakTitle = Font.system(size: 44, weight: .bold, design: .rounded)
        static let countdown = Font.system(size: 68, weight: .semibold, design: .rounded)
    }

    enum Spacing {
        static let small: CGFloat = 6
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 32
    }

    enum Radius {
        static let large: CGFloat = 20
    }

    enum Size {
        static let menuWidth: CGFloat = 340
        static let settingsWidth: CGFloat = 880
        static let settingsHeight: CGFloat = 640
        static let reminderWidth: CGFloat = 320
        static let reminderHeight: CGFloat = 112
        static let windowInset: CGFloat = 20
    }
}

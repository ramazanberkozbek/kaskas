import SwiftUI

enum Theme {
    enum Typography {
        static let status = Font.system(.headline, design: .rounded, weight: .semibold)
    }

    enum Spacing {
        static let medium: CGFloat = 12
    }

    enum Size {
        static let menuWidth: CGFloat = 240
        static let settingsWidth: CGFloat = 460
        static let settingsHeight: CGFloat = 240
    }
}

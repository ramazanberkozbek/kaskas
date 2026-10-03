import SwiftUI

/// Full-size notification cards and their scaled settings preview share type styles.
enum NotificationTypography {
    static func title(scale: CGFloat = 1) -> Font {
        .system(size: 17 * scale, weight: .bold, design: .rounded)
    }

    static func message(scale: CGFloat = 1) -> Font {
        .system(size: 13 * scale, weight: .medium)
    }

    static func action(scale: CGFloat = 1) -> Font {
        .system(size: 13 * scale, weight: .semibold)
    }
}

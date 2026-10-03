import SwiftUI

/// Shared by desktop notification cards, the cursor countdown and settings previews.
struct NotificationGlassBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        // The notification uses white text over any desktop wallpaper.
        .environment(\.colorScheme, .dark)
    }
}

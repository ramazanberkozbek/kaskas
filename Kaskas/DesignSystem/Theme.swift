import SwiftUI

enum Theme {
    enum Spacing {
        static let extraLarge: CGFloat = 32
    }

    enum Size {
        static let menuWidth: CGFloat = 340
        static let settingsWidth: CGFloat = 880
        static let settingsHeight: CGFloat = 640
    }
}

extension View {
    func dropdownHoverEffect() -> some View {
        modifier(DropdownHoverModifier())
    }
}

private struct DropdownHoverModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                    }
                    .opacity(isHovered && isEnabled ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { isHovered = $0 }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { isHovered = false }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered && isEnabled)
    }
}

import SwiftUI

struct AppearanceSettingsPicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        LabeledContent("settings.theme.title") {
            HStack(spacing: 20) {
                ForEach(AppAppearance.allCases) { appearance in
                    ThemeRadioButton(
                        title: appearance.titleKey,
                        isSelected: selection == appearance
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selection = appearance
                        }
                    }
                }
            }
        }
    }
}

private struct ThemeRadioButton: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color(red: 0.28, green: 0.79, blue: 0.36))
                            .frame(width: 14, height: 14)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4.5, height: 4.5)
                    } else {
                        Circle()
                            .fill(colorScheme == .dark
                                ? (isHovered ? Color(white: 0.32) : Color(white: 0.25))
                                : (isHovered ? Color(white: 0.74) : Color(white: 0.82)))
                            .frame(width: 14, height: 14)
                    }
                }

                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

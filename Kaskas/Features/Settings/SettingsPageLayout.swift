import SwiftUI

enum SettingsPageLayout {
    static let horizontalInset: CGFloat = 24
    static let topInset: CGFloat = 32
    static let bottomInset: CGFloat = 24
    static let sectionSpacing: CGFloat = 24
    static let cardInset: CGFloat = 16

    // macOS grouped forms supply these insets before contentMargins/padding.
    fileprivate static let formOuterInset: CGFloat = 20
    fileprivate static let formContentInset: CGFloat = 10
}

extension View {
    func settingsPageContent() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SettingsPageLayout.horizontalInset)
            .padding(.top, SettingsPageLayout.topInset)
            .padding(.bottom, SettingsPageLayout.bottomInset)
    }

    func settingsGroupedFormLayout() -> some View {
        formStyle(.grouped)
            .contentMargins(.horizontal, SettingsPageLayout.horizontalInset - SettingsPageLayout.formOuterInset, for: .scrollContent)
            .contentMargins(.top, SettingsPageLayout.topInset - SettingsPageLayout.formOuterInset, for: .scrollContent)
            .contentMargins(.bottom, SettingsPageLayout.bottomInset - SettingsPageLayout.formOuterInset, for: .scrollContent)
    }

    func settingsFormSectionHeader() -> some View {
        // Align native section headings with the outer edge of their cards.
        padding(.horizontal, -SettingsPageLayout.formContentInset)
    }

    func settingsFormRow() -> some View {
        padding(.horizontal, SettingsPageLayout.cardInset - SettingsPageLayout.formContentInset)
    }
}

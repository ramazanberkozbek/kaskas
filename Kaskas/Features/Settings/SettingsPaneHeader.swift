import SwiftUI

/// A page heading that scrolls with the pane's content.
struct SettingsPaneHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.primary)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

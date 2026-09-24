import AppKit
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("menu.ready")
                .font(Theme.Typography.status)

            Divider()

            SettingsLink {
                Label("menu.settings", systemImage: "gearshape")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("menu.quit", systemImage: "power")
            }
        }
        .padding(Theme.Spacing.medium)
        .frame(width: Theme.Size.menuWidth)
    }
}

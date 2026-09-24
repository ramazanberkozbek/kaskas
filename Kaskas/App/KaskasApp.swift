import SwiftUI

@main
struct KaskasApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            HStack(spacing: 4) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

                Text("app.name")
            }
        }

        Settings {
            SettingsView()
        }
    }
}

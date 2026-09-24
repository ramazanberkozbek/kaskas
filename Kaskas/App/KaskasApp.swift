import SwiftUI

@main
struct KaskasApp: App {
    @NSApplicationDelegateAdaptor(KaskasAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: appDelegate.sessionController)
        } label: {
            HStack(spacing: 4) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

                Text("app.name")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: appDelegate.sessionController)
        }
        .defaultSize(
            width: Theme.Size.settingsWidth,
            height: Theme.Size.settingsHeight
        )
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}

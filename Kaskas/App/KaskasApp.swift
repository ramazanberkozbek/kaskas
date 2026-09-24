import SwiftUI

@main
struct KaskasApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Label("app.name", systemImage: "timer")
        }

        Settings {
            SettingsView()
        }
    }
}

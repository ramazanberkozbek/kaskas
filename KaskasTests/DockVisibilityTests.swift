import AppKit
import Testing
@testable import Kaskas

@MainActor
struct DockVisibilityTests {
    @Test
    func togglingDockVisibilityKeepsOpenSettingsVisibleAndClosedSettingsClosed() async throws {
        let app = NSApplication.shared
        let originalPolicy = app.activationPolicy()
        let originalWindows = Set(app.windows.map(ObjectIdentifier.init))
        let suiteName = "DockVisibilityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let presenter = SettingsPresenter()
        let controller = SessionController(store: SessionStore(defaults: defaults), settingsPresenter: presenter)
        defer {
            presenter.dismiss()
            app.setActivationPolicy(originalPolicy)
            defaults.removePersistentDomain(forName: suiteName)
        }

        presenter.show(controller: controller)
        await finishWindowTransition()
        let window = try #require(app.windows.first { !originalWindows.contains(ObjectIdentifier($0)) && $0.title == "Kaskas" })
        defer { window.close() }

        // Repeat the round trip: restoring focus must not restore the Dock icon.
        for visible in [true, false, true, false] {
            var configuration = controller.configuration
            configuration.showInDock = visible
            controller.updateConfiguration(configuration)
            await finishWindowTransition()

            #expect(app.activationPolicy() == (visible ? .regular : .accessory))
            #expect(window.isVisible)
            #expect(!window.isMiniaturized)
            #expect(!app.isHidden)
            #expect(controller.configuration.showInDock == visible)
            #expect(SessionStore(defaults: defaults).loadConfiguration().showInDock == visible)
        }

        window.close()
        presenter.setDockVisibility(true)
        await finishWindowTransition()
        presenter.setDockVisibility(false)
        await finishWindowTransition()
        #expect(!window.isVisible)
        #expect(app.activationPolicy() == .accessory)
    }

    private func finishWindowTransition() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

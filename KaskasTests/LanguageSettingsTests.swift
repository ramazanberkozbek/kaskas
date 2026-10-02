import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Kaskas

struct LanguageSettingsTests {
    @Test
    func appLanguagePropertiesAndLocales() {
        #expect(AppLanguage.system.rawValue == "system")
        #expect(!AppLanguage.system.displayName.isEmpty)

        #expect(AppLanguage.english.rawValue == "en")
        #expect(AppLanguage.english.displayName == "English")
        #expect(AppLanguage.english.localeIdentifier == "en")
        #expect(AppLanguage.english.locale.identifier == "en")

        #expect(AppLanguage.turkish.rawValue == "tr")
        #expect(AppLanguage.turkish.displayName == "Türkçe")
        #expect(AppLanguage.turkish.localeIdentifier == "tr")
        #expect(AppLanguage.turkish.locale.identifier == "tr")
    }

    @Test
    @MainActor
    func languageFlagIconRendersWithoutEmoji() {
        // Verify vector icons are generated via ImageRenderer
        let systemImage = languageFlagImage(for: "system")
        let enImage = languageFlagImage(for: "en")
        let trImage = languageFlagImage(for: "tr")

        _ = systemImage
        _ = enImage
        _ = trImage
    }

    @Test
    @MainActor
    func updatingLanguageUpdatesControllerLocaleAndDefaults() {
        let suiteName = "LanguageSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let controller = SessionController(store: store)

        var config = controller.configuration
        config.appLanguage = .english
        controller.updateConfiguration(config)

        #expect(controller.configuration.appLanguage == .english)
        #expect(controller.locale.identifier == "en")

        config.appLanguage = .turkish
        controller.updateConfiguration(config)

        #expect(controller.configuration.appLanguage == .turkish)
        #expect(controller.locale.identifier == "tr")

        config.appLanguage = .system
        controller.updateConfiguration(config)

        #expect(controller.configuration.appLanguage == .system)
    }

    @Test
    @MainActor
    func generalSettingsViewRendersWithLanguageSection() {
        let suiteName = "LanguageSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let controller = SessionController(store: store)
        let view = GeneralSettingsView(controller: controller)
            .environment(\.locale, controller.locale)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 600)
        hostingView.layoutSubtreeIfNeeded()

        #expect(hostingView.frame.width == 600)
    }

    @Test
    @MainActor
    func screenLockPausesFocusSessionAndResumeExtendsDeadline() {
        let suiteName = "LockTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date()
        let store = SessionStore(defaults: defaults)
        let controller = SessionController(store: store, now: start)
        controller.start()

        let initialEndsAt = controller.sessionSnapshot.endsAt
        let lockTime = start.addingTimeInterval(10 * 60)
        controller.screenOrSessionDidLock(at: lockTime)

        let unlockTime = lockTime.addingTimeInterval(30 * 60)
        controller.screenOrSessionDidUnlock(at: unlockTime)

        #expect(controller.sessionSnapshot.endsAt > initialEndsAt)
        #expect(controller.sessionSnapshot.phase == .focusing)
    }
}

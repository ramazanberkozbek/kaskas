import Foundation
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

    @Test
    func dynamicLocalizationHelpersResolveCorrectLanguages() {
        let trLocale = Locale(identifier: "tr")
        let enLocale = Locale(identifier: "en")

        // 1. Categories
        #expect(AppCategory.coding.localizedName(for: trLocale) == "Yazılım")
        #expect(AppCategory.coding.localizedName(for: enLocale) == "Coding")
        #expect(AppCategory.browsing.localizedName(for: trLocale) == "İnternet")
        #expect(AppCategory.browsing.localizedName(for: enLocale) == "Browsing")
        #expect(AppCategory.productivity.localizedName(for: trLocale) == "Üretkenlik")
        #expect(AppCategory.productivity.localizedName(for: enLocale) == "Productivity")

        // 2. Break layout names
        #expect(localizedString("settings.breakLayout.horizon", locale: trLocale) == "Ufuk")
        #expect(localizedString("settings.breakLayout.horizon", locale: enLocale) == "Horizon")
        #expect(localizedString("settings.breakLayout.gentleBar", locale: trLocale) == "Zarif Çubuk")
        #expect(localizedString("settings.breakLayout.gentleBar", locale: enLocale) == "Gentle Bar")

        // 3. Durations
        let trMinutes = SessionDuration.minutesLabel(47 * 60, locale: trLocale)
        let enMinutes = SessionDuration.minutesLabel(47 * 60, locale: enLocale)
        #expect(trMinutes.contains("47") && trMinutes.contains("dk") && !trMinutes.contains("dk."))
        #expect(enMinutes.contains("47") && enMinutes.contains("min"))

        let trHours = StatisticsDuration.label(2 * 3600, locale: trLocale)
        let enHours = StatisticsDuration.label(2 * 3600, locale: enLocale)
        #expect(trHours.contains("2,0") && trHours.contains("sa") && !trHours.contains("sa."))
        #expect(enHours.contains("2.0") && enHours.contains("hr"))
    }
}

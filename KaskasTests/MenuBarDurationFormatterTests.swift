import Foundation
import Testing
@testable import Kaskas

struct MenuBarDurationFormatterTests {
    @Test
    func roundsUpAndSwitchesUnitsAtAnHour() {
        let locale = Locale(identifier: "en_US")
        #expect(MenuBarDurationFormatter.string(for: 0, locale: locale).contains("1 min"))
        #expect(MenuBarDurationFormatter.string(for: 59 * 60, locale: locale).contains("59 min"))
        #expect(MenuBarDurationFormatter.string(for: 59 * 60 + 1, locale: locale).contains("1 hr"))
        #expect(MenuBarDurationFormatter.string(for: 60 * 60 + 1, locale: locale).contains("1 hr 1 min"))
        #expect(MenuBarDurationFormatter.string(for: 120 * 60, locale: locale).contains("2 hr"))
    }

    @Test
    func usesLocaleSpecificUnitNames() {
        let turkish = MenuBarDurationFormatter.string(for: 65 * 60, locale: Locale(identifier: "tr_TR"))
        let english = MenuBarDurationFormatter.string(for: 65 * 60, locale: Locale(identifier: "en_US"))
        #expect(turkish.contains("sa"))
        #expect(turkish.contains("dk"))
        #expect(!turkish.contains("dk."))
        #expect(english.contains("hr"))
        #expect(english.contains("min"))
    }

    @Test
    func formatsScreenTimeStringAcrossUnderAnHourAndMultipleHours() {
        let trLocale = Locale(identifier: "tr_TR")
        let enLocale = Locale(identifier: "en_US")

        let trZero = MenuBarDurationFormatter.screenTimeString(for: 0, locale: trLocale)
        let enZero = MenuBarDurationFormatter.screenTimeString(for: 0, locale: enLocale)
        #expect(trZero.contains("0") && trZero.contains("dk"))
        #expect(enZero.contains("0") && enZero.contains("min"))

        let tr45 = MenuBarDurationFormatter.screenTimeString(for: 45 * 60, locale: trLocale)
        let en45 = MenuBarDurationFormatter.screenTimeString(for: 45 * 60, locale: enLocale)
        #expect(tr45.contains("45") && tr45.contains("dk"))
        #expect(en45.contains("45") && en45.contains("min"))

        let tr60 = MenuBarDurationFormatter.screenTimeString(for: 60 * 60, locale: trLocale)
        let en60 = MenuBarDurationFormatter.screenTimeString(for: 60 * 60, locale: enLocale)
        #expect(tr60.contains("1") && tr60.contains("sa") && !tr60.contains("sa."))
        #expect(en60.contains("1") && en60.contains("hr"))

        let tr135 = MenuBarDurationFormatter.screenTimeString(for: 135 * 60, locale: trLocale)
        let en135 = MenuBarDurationFormatter.screenTimeString(for: 135 * 60, locale: enLocale)
        #expect(tr135.contains("2") && tr135.contains("sa") && tr135.contains("15") && tr135.contains("dk"))
        #expect(en135.contains("2") && en135.contains("hr") && en135.contains("15") && en135.contains("min"))
    }
}

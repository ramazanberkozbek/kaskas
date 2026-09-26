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
}

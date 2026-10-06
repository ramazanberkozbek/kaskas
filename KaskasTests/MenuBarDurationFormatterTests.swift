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

    @Test
    func formatsActiveHoursResumeStringForTodayTomorrowAndFutureWeekdays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let trLocale = Locale(identifier: "tr_TR")
        let enLocale = Locale(identifier: "en_US")

        var nowComponents = DateComponents()
        nowComponents.year = 2026
        nowComponents.month = 10
        nowComponents.day = 6
        nowComponents.hour = 20
        nowComponents.minute = 0
        let now = try #require(calendar.date(from: nowComponents))

        var todayComponents = nowComponents
        todayComponents.hour = 22
        let today = try #require(calendar.date(from: todayComponents))

        var tomorrowComponents = nowComponents
        tomorrowComponents.day = 7
        tomorrowComponents.hour = 9
        let tomorrow = try #require(calendar.date(from: tomorrowComponents))

        var futureComponents = nowComponents
        futureComponents.day = 9
        futureComponents.hour = 9
        let futureDay = try #require(calendar.date(from: futureComponents))

        let trToday = MenuBarDurationFormatter.activeHoursResumeString(for: today, relativeTo: now, calendar: calendar, locale: trLocale)
        #expect(trToday.contains("Devam:"))
        #expect(trToday.contains("Bugün"))

        let trTomorrow = MenuBarDurationFormatter.activeHoursResumeString(for: tomorrow, relativeTo: now, calendar: calendar, locale: trLocale)
        #expect(trTomorrow.contains("Devam:"))
        #expect(trTomorrow.contains("Yarın"))
        #expect(!trTomorrow.contains("Çar"))

        let trFuture = MenuBarDurationFormatter.activeHoursResumeString(for: futureDay, relativeTo: now, calendar: calendar, locale: trLocale)
        #expect(trFuture.contains("Devam:"))
        #expect(trFuture.contains("Cuma"))
        #expect(!trFuture.contains("Cum "))

        let enToday = MenuBarDurationFormatter.activeHoursResumeString(for: today, relativeTo: now, calendar: calendar, locale: enLocale)
        #expect(enToday.contains("Resumes"))
        #expect(enToday.contains("today"))

        let enTomorrow = MenuBarDurationFormatter.activeHoursResumeString(for: tomorrow, relativeTo: now, calendar: calendar, locale: enLocale)
        #expect(enTomorrow.contains("Resumes"))
        #expect(enTomorrow.contains("tomorrow"))
        #expect(!enTomorrow.contains("Wed"))

        let enFuture = MenuBarDurationFormatter.activeHoursResumeString(for: futureDay, relativeTo: now, calendar: calendar, locale: enLocale)
        #expect(enFuture.contains("Resumes"))
        #expect(enFuture.contains("Friday"))
        #expect(!enFuture.contains("Fri "))
    }
}

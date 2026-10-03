import Foundation
import Testing
@testable import Kaskas

struct DurationInputTests {
    @Test func acceptsSecondsAndLocalizedFractionalMinutes() {
        #expect(DurationInput.seconds(from: "15", unit: .seconds, locale: Locale(identifier: "en_US")) == 15)
        #expect(DurationInput.seconds(from: "1.5", unit: .minutes, locale: Locale(identifier: "en_US")) == 90)
        #expect(DurationInput.seconds(from: "1,5", unit: .minutes, locale: Locale(identifier: "tr_TR")) == 90)
        #expect(DurationInput.seconds(from: "2", unit: .hours, locale: Locale(identifier: "tr_TR")) == 7_200)
    }

    @Test func rejectsInvalidOrUnsafeInput() {
        for input in ["", "0", "-5", "12abc", "nan", "inf", "1e100", "0.5"] {
            #expect(DurationInput.seconds(from: input, unit: .seconds, locale: Locale(identifier: "en_US")) == nil)
        }
    }

    @Test func limitsCustomDurationsTo240Minutes() {
        let locale = Locale(identifier: "tr_TR")
        #expect(DurationInput.seconds(from: "240", unit: .minutes, locale: locale) == 14_400)
        #expect(DurationInput.seconds(from: "239,5", unit: .minutes, locale: locale) == 14_370)
        #expect(DurationInput.seconds(from: "240,5", unit: .minutes, locale: locale) == nil)
        #expect(DurationInput.seconds(from: "241", unit: .minutes, locale: locale) == nil)
        #expect(DurationInput.seconds(from: "5", unit: .hours, locale: locale) == nil)
        #expect(DurationInput.seconds(from: "241", unit: .minutes, locale: locale,
                                      maximum: .greatestFiniteMagnitude) == nil)
    }

    @Test func preservesConfigurationLimits() {
        let locale = Locale(identifier: "en_US")
        #expect(DurationInput.seconds(from: "15", unit: .seconds, locale: locale,
                                      minimum: 5, maximum: 30, step: 5) == 15)
        for input in ["4", "17", "31"] {
            #expect(DurationInput.seconds(from: input, unit: .seconds, locale: locale,
                                          minimum: 5, maximum: 30, step: 5) == nil)
        }
        #expect(DurationInput.seconds(from: "59", unit: .seconds, locale: locale, minimum: 60) == nil)
        #expect(DurationInput.seconds(from: "1", unit: .minutes, locale: locale, minimum: 60) == 60)
    }

    @Test func clampsAndStepsDurationsProperly() {
        // Minutes clamped to 240
        #expect(DurationInput.clampedSeconds(from: 250, unit: .minutes) == 14_400)
        #expect(DurationInput.clampedSeconds(from: 240, unit: .minutes) == 14_400)
        #expect(DurationInput.clampedSeconds(from: 2_343_241, unit: .minutes) == 14_400)

        // Minutes clamped to minimum 1
        #expect(DurationInput.clampedSeconds(from: 0, unit: .minutes) == 60)
        #expect(DurationInput.clampedSeconds(from: -5, unit: .minutes) == 60)
        #expect(DurationInput.clampedSeconds(from: 20, unit: .minutes) == 1_200)

        // Seconds with bounds and steps (e.g. 5–30s in steps of 5)
        #expect(DurationInput.clampedSeconds(from: 16, unit: .seconds, minimum: 5, maximum: 30, step: 5) == 15)
        #expect(DurationInput.clampedSeconds(from: 18, unit: .seconds, minimum: 5, maximum: 30, step: 5) == 20)
        #expect(DurationInput.clampedSeconds(from: 35, unit: .seconds, minimum: 5, maximum: 30, step: 5) == 30)
        #expect(DurationInput.clampedSeconds(from: 3, unit: .seconds, minimum: 5, maximum: 30, step: 5) == 5)
        #expect(DurationInput.clampedSeconds(from: 0, unit: .seconds, minimum: 5, maximum: 30, step: 5) == 5)
    }
}

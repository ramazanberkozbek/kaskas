import Testing
@testable import Kaskas

struct SettingsTimeInputTests {
    @Test(arguments: [
        ("12:3", 12 * 60 + 3),
        ("09:3", 9 * 60 + 3),
        ("123", 12 * 60 + 3),
        ("9:3", 9 * 60 + 3),
        ("9:30", 9 * 60 + 30),
        ("12:30", 12 * 60 + 30),
        ("9", 9 * 60),
        ("12:", 12 * 60),
        ("00:00", 0),
        ("23:59", 23 * 60 + 59),
    ] as [(String, Int)])
    func savingFormattedInputPreservesHoursAndMinutes(_ text: String, _ expectedMinute: Int) {
        let formatted = SettingsTimeInput.format(text, replacing: "")
        #expect(SettingsTimeInput.minute(from: formatted) == expectedMinute)
    }

    @Test(arguments: ["", "24:00", "12:60", "12::30", "12:345", ":30", "abc"])
    func rejectsInvalidTimes(_ text: String) {
        #expect(SettingsTimeInput.minute(from: text) == nil)
    }

    @Test
    func typingAndBackspacingPreserveTheTimeFields() {
        let typedHour = SettingsTimeInput.format("12", replacing: "1")
        #expect(typedHour == "12:")
        let firstMinuteDigit = SettingsTimeInput.format("12:3", replacing: typedHour)
        #expect(firstMinuteDigit == "12:3")
        let completeTime = SettingsTimeInput.format("12:34", replacing: firstMinuteDigit)
        #expect(completeTime == "12:34")
        #expect(SettingsTimeInput.minute(from: completeTime) == 12 * 60 + 34)
        #expect(SettingsTimeInput.format("12", replacing: typedHour) == "1")
    }
}

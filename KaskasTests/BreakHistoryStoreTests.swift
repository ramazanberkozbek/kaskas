import Foundation
import SwiftData
import Testing
@testable import Kaskas

@MainActor
struct BreakHistoryStoreTests {
    private func makeStore() throws -> BreakHistoryStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BreakRecord.self, configurations: configuration)
        return BreakHistoryStore(container: container)
    }

    @Test
    func storesOneEntryPerBreakAndFetchesOnlyTheRequestedDates() throws {
        let store = try makeStore()
        let day = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let firstSession = FocusSession(
            phase: .onBreak,
            startedAt: day,
            endsAt: day.addingTimeInterval(300),
            nextMicroReminderAt: nil
        )
        let first = BreakHistoryEntry.transition(
            from: firstSession,
            at: day.addingTimeInterval(120),
            outcome: .completed,
            source: .manual
        )
        let secondSession = FocusSession(
            phase: .focusing,
            startedAt: day.addingTimeInterval(86_400),
            endsAt: day.addingTimeInterval(89_100),
            nextMicroReminderAt: nil
        )
        let second = BreakHistoryEntry.transition(
            from: secondSession,
            at: day.addingTimeInterval(87_000),
            outcome: .skipped,
            source: .manual
        )

        try store.insert(first)
        try store.insert(first)
        try store.insert(second)

        #expect(try store.entries(from: day, to: day.addingTimeInterval(86_400)) == [first])
        #expect(try store.entries(from: day, to: day.addingTimeInterval(172_800)) == [first, second])
    }

    @Test
    func importsOldSmartPauseRecordsWithoutDuplicates() throws {
        let suiteName = "BreakHistoryStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let focusStart = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let stoppedAt = focusStart.addingTimeInterval(900)
        let returnedAt = stoppedAt.addingTimeInterval(60)
        let legacyJSON: [String: Any] = [
            "smartPauseRecords": [[
                "focusStartedAt": focusStart.timeIntervalSinceReferenceDate,
                "focusStoppedAt": stoppedAt.timeIntervalSinceReferenceDate,
                "returnedAt": returnedAt.timeIntervalSinceReferenceDate,
                "focusedDuration": 900.0
            ]]
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: "sessionState")

        let sessionStore = SessionStore(defaults: defaults)
        let historyStore = try makeStore()
        try historyStore.importLegacyRecords(from: sessionStore)
        try historyStore.importLegacyRecords(from: sessionStore)

        let entries = try historyStore.entries(
            from: focusStart,
            to: returnedAt.addingTimeInterval(1)
        )
        #expect(entries.count == 1)
        #expect(entries.first?.source == .smartPause)
        #expect(entries.first?.outcome == .completed)
        #expect(entries.first?.focusStartedAt == focusStart)
        #expect(entries.first?.focusedDuration == 900)
    }
}

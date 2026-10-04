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
    func storesOneEntryPerBreakAndFetchesOnlyTheRequestedDates() async throws {
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

        try await store.insert(first)
        try await store.insert(first)
        try await store.insert(second)

        #expect(try store.entries(from: day, to: day.addingTimeInterval(86_400)) == [first])
        #expect(try store.entries(from: day, to: day.addingTimeInterval(172_800)) == [first, second])
    }
}

import Foundation
import Testing
@testable import Kaskas

@MainActor
struct SessionPersistenceTests {
    private enum WriteFailure: Error { case unavailable }

    private final class RecordingHistory: BreakHistoryRecording {
        var shouldFail = true
        var entries: [BreakHistoryEntry] = []

        func insert(_ entry: BreakHistoryEntry) throws {
            if shouldFail { throw WriteFailure.unavailable }
            if !entries.contains(where: { $0.id == entry.id }) { entries.append(entry) }
        }
    }

    @Test
    func historyFailureStillSavesSessionAndRetriesAfterRestart() async throws {
        let suiteName = "SessionPersistenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let history = RecordingHistory()
        let date = Date(timeIntervalSinceReferenceDate: 1_000_000)
        var engine = SessionEngine(now: date)
        engine.send(.startBreakNow, at: date)
        let record = BreakHistoryEntry.transition(
            from: engine.session,
            at: date.addingTimeInterval(60),
            outcome: .completed,
            source: .manual
        )
        engine.send(.completeBreak, at: date.addingTimeInterval(60))

        let firstPersistence = SessionPersistence(store: store, historyStore: history)
        firstPersistence.save(state: engine.state, record: record)
        await firstPersistence.waitForPersistence()
        #expect(firstPersistence.historySaveFailed)
        #expect(store.loadSessionState() == engine.state)
        #expect(store.loadPendingHistoryEntries() == [record])

        history.shouldFail = false
        let restoredPersistence = SessionPersistence(store: store, historyStore: history)
        restoredPersistence.save(state: engine.state)
        restoredPersistence.save(state: engine.state)
        await restoredPersistence.waitForPersistence()
        #expect(!restoredPersistence.historySaveFailed)
        #expect(history.entries == [record])
        #expect(store.loadPendingHistoryEntries().isEmpty)
    }

    @Test
    func unavailableHistoryStoreDoesNotPreventSessionRestore() throws {
        let suiteName = "SessionPersistenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let date = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let engine = SessionEngine(now: date)
        let record = BreakHistoryEntry.transition(
            from: engine.session,
            at: date.addingTimeInterval(60),
            outcome: .skipped,
            source: .manual
        )

        let persistence = SessionPersistence(store: store, historyStore: nil)
        persistence.save(state: engine.state, record: record)

        #expect(persistence.historySaveFailed)
        #expect(store.loadSessionState() == engine.state)
        #expect(store.loadPendingHistoryEntries() == [record])
    }
}

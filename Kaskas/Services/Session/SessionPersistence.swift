import Foundation

/// Saves active session state and flushes completed break history entries.
@MainActor
final class SessionPersistence {
    private(set) var historySaveFailed = false
    private let store: SessionStore
    private let historyStore: (any BreakHistoryRecording)?
    private var pendingEntries: [BreakHistoryEntry]

    init(store: SessionStore, historyStore: (any BreakHistoryRecording)?) {
        self.store = store
        self.historyStore = historyStore
        historySaveFailed = historyStore == nil
        pendingEntries = store.loadPendingHistoryEntries()
    }

    func save(state: SessionState, record: BreakHistoryEntry? = nil) {
        if let record {
            pendingEntries.append(record)
            // Write the outbox first so a crash cannot lose a completed break.
            store.save(pendingHistoryEntries: pendingEntries)
        }
        store.save(state: state)

        guard let historyStore, !pendingEntries.isEmpty else { return }
        do {
            for entry in pendingEntries {
                try historyStore.insert(entry)
            }
            pendingEntries.removeAll()
            store.save(pendingHistoryEntries: pendingEntries)
            historySaveFailed = false
        } catch {
            historySaveFailed = true
            NSLog("Kaskas: Failed to save break history: %@", String(describing: error))
        }
    }
}

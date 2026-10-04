import Foundation

/// Saves the durable outbox before enqueuing completed break history batches.
@MainActor
final class SessionPersistence {
    private(set) var historySaveFailed = false {
        didSet { if historySaveFailed != oldValue { onHistoryFailureChanged?(historySaveFailed) } }
    }
    var onHistoryFailureChanged: ((Bool) -> Void)?
    var bufferedHistoryEntries: [BreakHistoryEntry] { pendingEntries }
    private let store: SessionStore
    private let historyStore: (any BreakHistoryRecording)?
    private var persistenceTask: Task<Void, Never>?
    private var persistenceRequested = false
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

        schedulePersistence()
    }

    private func schedulePersistence() {
        guard historyStore != nil, !pendingEntries.isEmpty else { return }
        persistenceRequested = true
        guard persistenceTask == nil else { return }
        persistenceTask = Task {
            while persistenceRequested {
                persistenceRequested = false
                guard let historyStore, !pendingEntries.isEmpty else { continue }
                let batch = pendingEntries
                do {
                    try await historyStore.insertBatch(batch)
                    let committed = Set(batch.map(\.id))
                    pendingEntries.removeAll { committed.contains($0.id) }
                    store.save(pendingHistoryEntries: pendingEntries)
                    historySaveFailed = false
                } catch {
                    historySaveFailed = true
                    NSLog("Kaskas: Failed to save break history: %@", String(describing: error))
                }
            }
            persistenceTask = nil
        }
    }

    nonisolated static func mergeEntries(_ persisted: [BreakHistoryEntry], buffered: [BreakHistoryEntry],
        from start: Date, to end: Date) -> [BreakHistoryEntry] {
        var byID: [String: BreakHistoryEntry] = [:]
        for entry in persisted { byID[entry.id] = entry }
        for entry in buffered { byID[entry.id] = entry }
        return byID.values.filter { $0.occurredAt >= start && $0.occurredAt < end }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    @concurrent static func mergeEntriesAsync(_ persisted: [BreakHistoryEntry], buffered: [BreakHistoryEntry],
        from start: Date, to end: Date) async -> [BreakHistoryEntry] {
        mergeEntries(persisted, buffered: buffered, from: start, to: end)
    }

    func waitForPersistence() async {
        await persistenceTask?.value
    }
}

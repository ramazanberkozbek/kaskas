import Foundation
import SwiftData

/// Serial database writer. Contexts and models are created and used only on this
/// actor; callers send immutable values and acknowledge IDs only after save.
actor HistoryWriteWorker {
    private let container: ModelContainer
    private var ownedContext: ModelContext?

    init(container: ModelContainer) { self.container = container }

    private var context: ModelContext {
        if let ownedContext { return ownedContext }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        ownedContext = context
        return context
    }

    /// Delete all history in one transaction after the callers drain their writers.
    func deleteAllHistory() throws {
        let context = context
        do {
            for record in try context.fetch(FetchDescriptor<ActivityRecord>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<AppUsageRecord>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<BreakRecord>()) { context.delete(record) }
            if container.schema.entities.contains(where: { $0.name == "ExcludedUsageRecord" }) {
                for record in try context.fetch(FetchDescriptor<ExcludedUsageRecord>()) { context.delete(record) }
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func insert(_ values: [ActivityInterval]) throws {
        let context = context
        do {
            // Bound each duplicate query; a single transaction still covers the batch.
            for offset in stride(from: 0, to: values.count, by: 256) {
                let chunk = values[offset..<min(offset + 256, values.count)]
                let ids = chunk.map(\.id)
                let query = FetchDescriptor<ActivityRecord>(predicate: #Predicate { ids.contains($0.recordID) })
                var existing = Set(try context.fetch(query).map(\.recordID))
                for value in chunk where existing.insert(value.id).inserted { context.insert(ActivityRecord(value)) }
            }
            if context.hasChanges { try context.save() }
        } catch { context.rollback(); throw error }
    }

    func insert(_ values: [AppUsageSegment]) throws {
        let context = context
        do {
            for offset in stride(from: 0, to: values.count, by: 256) {
                let chunk = values[offset..<min(offset + 256, values.count)]
                let ids = chunk.map(\.id)
                let query = FetchDescriptor<AppUsageRecord>(predicate: #Predicate { ids.contains($0.recordID) })
                var existing = Set(try context.fetch(query).map(\.recordID))
                for value in chunk where existing.insert(value.id).inserted { context.insert(AppUsageRecord(value)) }
            }
            if context.hasChanges { try context.save() }
        } catch { context.rollback(); throw error }
    }

    func insert(_ values: [ExcludedUsageInterval]) throws {
        let context = context
        do {
            for offset in stride(from: 0, to: values.count, by: 256) {
                let chunk = values[offset..<min(offset + 256, values.count)]
                let ids = chunk.map(\.id)
                let query = FetchDescriptor<ExcludedUsageRecord>(predicate: #Predicate { ids.contains($0.recordID) })
                var existing = Set(try context.fetch(query).map(\.recordID))
                for value in chunk where existing.insert(value.id).inserted { context.insert(ExcludedUsageRecord(value)) }
            }
            if context.hasChanges { try context.save() }
        } catch { context.rollback(); throw error }
    }

    func insert(_ values: [BreakHistoryEntry]) throws {
        let context = context
        do {
            for offset in stride(from: 0, to: values.count, by: 256) {
                let chunk = values[offset..<min(offset + 256, values.count)]
                let ids = chunk.map(\.id)
                let query = FetchDescriptor<BreakRecord>(predicate: #Predicate { ids.contains($0.recordID) })
                var existing = Set(try context.fetch(query).map(\.recordID))
                for value in chunk where existing.insert(value.id).inserted { context.insert(BreakRecord(value)) }
            }
            if context.hasChanges { try context.save() }
        } catch { context.rollback(); throw error }
    }
}

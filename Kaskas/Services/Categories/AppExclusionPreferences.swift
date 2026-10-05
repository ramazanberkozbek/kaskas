import Foundation
import Observation

nonisolated struct ExcludedApplication: Codable, Equatable, Identifiable, Sendable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

nonisolated struct AppExclusionSnapshot: Sendable {
    let identifiers: Set<String>
    static let empty = Self(identifiers: [])

    func contains(_ app: ForegroundApp) -> Bool {
        contains(bundleID: app.bundleID)
    }

    func contains(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return identifiers.contains(CategoryResolver.normalize(bundleID))
    }
}

/// Independent of category rules: removing an exclusion restores its assignment.
@MainActor
@Observable
final class AppExclusionPreferences {
    private static let storageKey = "kaskas_excluded_applications"
    private let defaults: UserDefaults
    private(set) var applications: [ExcludedApplication]
    private(set) var revision = 0
    @ObservationIgnored var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([ExcludedApplication].self, from: $0) } ?? []
        var seen: Set<String> = []
        applications = saved.compactMap { app in
            let identifier = CategoryResolver.normalize(app.bundleID)
            guard !identifier.isEmpty, seen.insert(identifier).inserted else { return nil }
            return .init(bundleID: identifier, name: app.name)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func snapshot() -> AppExclusionSnapshot {
        .init(identifiers: Set(applications.map(\.bundleID)))
    }

    func add(_ apps: [ExcludedApplication]) {
        var byID = Dictionary(uniqueKeysWithValues: applications.map { ($0.bundleID, $0) })
        for app in apps {
            let identifier = CategoryResolver.normalize(app.bundleID)
            guard !identifier.isEmpty else { continue }
            byID[identifier] = .init(bundleID: identifier, name: app.name)
        }
        commit(byID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }

    func remove(bundleID: String) {
        let identifier = CategoryResolver.normalize(bundleID)
        commit(applications.filter { $0.bundleID != identifier })
    }

    private func commit(_ values: [ExcludedApplication]) {
        guard values != applications, let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: Self.storageKey)
        applications = values
        revision += 1
        onChange?()
    }
}

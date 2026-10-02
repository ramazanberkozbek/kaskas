import Foundation

nonisolated struct CategoryResolution: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        case userRule, builtInRule, legacyNameRule, suppressed, ambiguous, unmatched
    }

    let categoryID: String
    let source: Source
    let ruleKey: String?

    static let unmatched = Self(categoryID: "other", source: .unmatched, ruleKey: nil)

    var isResolved: Bool {
        switch source {
        case .userRule, .builtInRule, .legacyNameRule: true
        case .suppressed, .ambiguous, .unmatched: false
        }
    }
}

/// An immutable index. Presentation order and application discovery never affect matching.
nonisolated struct CategoryResolver: Sendable {
    private let customByID: [String: CategoryRule]
    private let defaultByID: [String: CategoryRule]
    private let customByName: [String: [CategoryRule]]
    private let defaultByName: [String: [CategoryRule]]
    private let categoryIDs: Set<String>

    init(customRules: [CategoryRule], defaultRules: [CategoryRule], suppressed: Set<String> = [], categoryIDs: Set<String>) {
        func byID(_ rules: [CategoryRule]) -> [String: CategoryRule] {
            var result: [String: CategoryRule] = [:]
            for rule in rules { result[Self.normalize(rule.appIdentifier)] = rule }
            return result
        }
        func byName(_ rules: [CategoryRule]) -> [String: [CategoryRule]] {
            var result: [String: [CategoryRule]] = [:]
            for rule in rules {
                for name in Set([Self.normalize(rule.displayName), Self.normalize(rule.appIdentifier)]) where !name.isEmpty {
                    result[name, default: []].append(rule)
                }
            }
            return result
        }
        customByID = byID(customRules)
        defaultByID = byID(defaultRules)
        customByName = byName(customRules)
        defaultByName = byName(defaultRules)
        self.categoryIDs = categoryIDs
    }

    func resolve(bundleID: String?, appName: String?) -> CategoryResolution {
        let identifier = Self.normalize(bundleID ?? "")
        if !identifier.isEmpty {
            if let rule = customByID[identifier] { return resolution(rule, source: .userRule) }
            if let rule = defaultByID[identifier] { return resolution(rule, source: .builtInRule) }
            return .unmatched
        }
        let name = Self.normalize(appName ?? "")
        guard !name.isEmpty else { return .unmatched }
        let matches = customByName[name] ?? defaultByName[name] ?? []
        guard matches.count == 1, let rule = matches.first else {
            return matches.isEmpty ? .unmatched : CategoryResolution(categoryID: "other", source: .ambiguous, ruleKey: nil)
        }
        return resolution(rule, source: .legacyNameRule)
    }

    private func resolution(_ rule: CategoryRule, source: CategoryResolution.Source) -> CategoryResolution {
        CategoryResolution(
            categoryID: categoryIDs.contains(rule.categoryId) ? rule.categoryId : "other",
            source: source,
            ruleKey: Self.normalize(rule.appIdentifier)
        )
    }

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

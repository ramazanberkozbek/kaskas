import Foundation

nonisolated public struct CategoryRule: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var appIdentifier: String  // Bundle ID (e.g. com.apple.dt.Xcode) or process name (e.g. Xcode)
    public var displayName: String    // Human readable name (e.g. Xcode)
    public var categoryId: String     // Maps to AppCategory.id
    public var isDefault: Bool        // Built-in rule vs user-created rule

    public init(
        id: UUID = UUID(),
        appIdentifier: String,
        displayName: String,
        categoryId: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.appIdentifier = appIdentifier
        self.displayName = displayName
        self.categoryId = categoryId
        self.isDefault = isDefault
    }

    /// Checks if this rule matches a given bundle ID or application name.
    public func matches(bundleId: String?, appName: String?) -> Bool {
        let idPattern = appIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let namePattern = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let bundleId = bundleId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !bundleId.isEmpty {
            return bundleId == idPattern
        }

        if let appName = appName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !appName.isEmpty {
            if appName == idPattern || (!namePattern.isEmpty && appName == namePattern) {
                return true
            }
        }

        return false
    }
}

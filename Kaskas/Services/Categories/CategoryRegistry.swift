import AppKit
import Foundation
import Observation

/// Resolves application categories and manages custom user rules.
@MainActor
@Observable
public final class CategoryRegistry {
    private enum StorageKey {
        static let customRules = "kaskas_category_custom_rules"
        static let customCategories = "kaskas_category_custom_categories"
        static let archivedCategories = "kaskas_category_archived_categories"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public private(set) var customRules: [CategoryRule] = []
    public private(set) var customCategories: [AppCategory] = []

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var cachedResolver: CategoryResolver?
    public private(set) var archivedCategories: [AppCategory] = []

    private func didChange() {
        cachedResolver = nil
        onChange?()
    }

    func resolution(bundleID: String?, appName: String?) -> CategoryResolution {
        if let cachedResolver { return cachedResolver.resolve(bundleID: bundleID, appName: appName) }
        let resolver = CategoryResolver(customRules: customRules, defaultRules: Self.defaultRules,
            categoryIDs: Set(categories.map(\.id)))
        cachedResolver = resolver
        return resolver.resolve(bundleID: bundleID, appName: appName)
    }

    func historicalCategory(for id: String) -> AppCategory? {
        category(for: id) ?? archivedCategories.first { $0.id == id } ?? AppCategory.defaultCategories.first { $0.id == id }
    }

    private func archive(_ category: AppCategory) {
        archivedCategories.removeAll { $0.id == category.id }
        archivedCategories.append(category)
        if let data = try? encoder.encode(archivedCategories) { defaults.set(data, forKey: StorageKey.archivedCategories) }
    }

    private static var cachedApps: [DiscoveredApp]?
    private static let iconCache = NSCache<NSString, NSImage>()
    private static var installedIdentifiersCache: Set<String>?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCustomData()
    }

    // MARK: - Categories

    public var categories: [AppCategory] {
        var result = AppCategory.defaultCategories.filter { !hiddenBuiltInCategoryIds.contains($0.id) }
        for custom in customCategories {
            if let index = result.firstIndex(where: { $0.id == custom.id }) {
                result[index] = custom
            } else {
                result.append(custom)
            }
        }
        return result
    }

    public func category(for id: String) -> AppCategory? {
        categories.first { $0.id == id }
    }

    @discardableResult
    public func addOrUpdateCategory(name: String, iconName: String, colorName: String, id: String? = nil) -> AppCategory {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryId = id ?? UUID().uuidString.lowercased()

        let category = AppCategory(
            id: categoryId,
            name: cleanName.isEmpty ? String(localized: "categories.newCategoryFallback") : cleanName,
            iconName: iconName.isEmpty ? "folder.fill" : iconName,
            colorName: colorName.isEmpty ? "blue" : colorName,
            isBuiltIn: false
        )

        if let existingIdx = customCategories.firstIndex(where: { $0.id == categoryId }) {
            customCategories[existingIdx] = category
        } else {
            customCategories.append(category)
        }
        saveCustomCategories()
        didChange()
        return category
    }

    /// IDs of built-in categories that the user has chosen to hide.
    public private(set) var hiddenBuiltInCategoryIds: Set<String> = []

    private static let hiddenCategoriesKey = "kaskas_hidden_builtin_categories"

    /// App identifiers of built-in rules that the user has chosen to suppress.
    public private(set) var suppressedDefaultRuleIdentifiers: Set<String> = []

    private static let suppressedRulesKey = "kaskas_suppressed_default_rules"

    public func removeCategory(id: String) {
        // Never allow deleting the "other" fallback category
        guard id != AppCategory.other.id else { return }
        if let category = category(for: id) { archive(category) }

        // If it's a built-in category, mark it as hidden instead of deleting
        if AppCategory.defaultCategories.contains(where: { $0.id == id }) {
            hiddenBuiltInCategoryIds.insert(id)
            saveHiddenCategories()
        }

        customCategories.removeAll { $0.id == id }
        saveCustomCategories()

        // Reassign any custom rules targeting this deleted category to other
        var rulesModified = false
        for index in customRules.indices where customRules[index].categoryId == id {
            customRules[index].categoryId = AppCategory.other.id
            rulesModified = true
        }
        if rulesModified {
            saveCustomRules()
        }
        didChange()
    }

    private func saveHiddenCategories() {
        defaults.set(Array(hiddenBuiltInCategoryIds), forKey: Self.hiddenCategoriesKey)
    }

    private func loadHiddenCategories() {
        if let saved = defaults.stringArray(forKey: Self.hiddenCategoriesKey) {
            hiddenBuiltInCategoryIds = Set(saved)
        }
    }

    private func saveCustomCategories() {
        if let data = try? encoder.encode(customCategories) {
            defaults.set(data, forKey: StorageKey.customCategories)
        }
    }

    // MARK: - Rules

    public var allRules: [CategoryRule] {
        var merged: [CategoryRule] = []
        var seenIdentifiers = Set<String>()

        // Custom rules take precedence
        for custom in customRules {
            let key = custom.appIdentifier.lowercased()
            if seenIdentifiers.insert(key).inserted {
                merged.append(custom)
            }
        }

        // Add defaults if not overridden and not suppressed
        for def in Self.defaultRules {
            let key = def.appIdentifier.lowercased()
            if !suppressedDefaultRuleIdentifiers.contains(key) && seenIdentifiers.insert(key).inserted {
                merged.append(def)
            }
        }

        return merged.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Returns only rules for applications that are installed on this Mac (or user custom rules).
    public var installedRules: [CategoryRule] {
        allRules.filter { rule in
            if !rule.isDefault { return true }
            return Self.isAppInstalled(bundleId: rule.appIdentifier, appName: rule.displayName)
        }
    }

    public static func isAppInstalled(bundleId: String, appName: String) -> Bool {
        let lowBundle = bundleId.lowercased()
        let lowName = appName.lowercased()

        if lowBundle == Bundle.main.bundleIdentifier?.lowercased() { return true }

        if let cache = installedIdentifiersCache {
            if (!lowBundle.isEmpty && cache.contains(lowBundle)) || (!lowName.isEmpty && cache.contains(lowName)) { return true }
            return !bundleId.isEmpty && NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        }

        // Build set cache for all subsequent lookups
        var identifiers = Set<String>()
        let apps = cachedApps ?? []
        for app in apps {
            if !app.bundleId.isEmpty { identifiers.insert(app.bundleId.lowercased()) }
            if !app.name.isEmpty { identifiers.insert(app.name.lowercased()) }
        }
        installedIdentifiersCache = identifiers

        if (!lowBundle.isEmpty && identifiers.contains(lowBundle)) || (!lowName.isEmpty && identifiers.contains(lowName)) {
            return true
        }

        // Fallback: workspace check for system utilities that might not be in query index
        if !bundleId.isEmpty, NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil {
            return true
        }

        return false
    }

    public static func iconForApp(bundleId: String, appName: String, path: String? = nil) -> NSImage? {
        let cacheKey = (!bundleId.isEmpty ? bundleId : ((path != nil && !path!.isEmpty) ? path! : appName)).lowercased() as NSString
        if let cached = iconCache.object(forKey: cacheKey) {
            return cached
        }

        var image: NSImage?
        if let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            image = NSWorkspace.shared.icon(forFile: path)
        } else if !bundleId.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleId || $0.localizedName == appName
        }) {
            image = app.icon
        } else {
            let searchName = appName.hasSuffix(".app") ? appName : "\(appName).app"
            let standardPaths = AppDiscoveryService.standardApplicationDirectories
            for basePath in standardPaths {
                let appPath = (basePath as NSString).appendingPathComponent(searchName)
                if FileManager.default.fileExists(atPath: appPath) {
                    image = NSWorkspace.shared.icon(forFile: appPath)
                    break
                }
            }
            if image == nil {
                let lowBundle = bundleId.lowercased()
                let lowName = appName.lowercased()
                if let found = cachedApps?.first(where: {
                    (!bundleId.isEmpty && $0.bundleId.lowercased() == lowBundle) ||
                    (!appName.isEmpty && $0.name.lowercased() == lowName)
                }), !found.path.isEmpty, FileManager.default.fileExists(atPath: found.path) {
                    image = NSWorkspace.shared.icon(forFile: found.path)
                }
            }
        }

        if let image {
            iconCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    nonisolated public struct DiscoveredApp: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let bundleId: String
        public let path: String

        public init(id: String, name: String, bundleId: String, path: String) {
            self.id = id
            self.name = name
            self.bundleId = bundleId
            self.path = path
        }
    }

    public static func discoverInstalledApplications(forceRefresh: Bool = false) -> [DiscoveredApp] {
        if !forceRefresh, let cached = cachedApps { return cached }
        return finalizeDiscoveredApps(AppDiscoveryService.performDiskDiscovery())
    }

    public static func discoverInstalledApplicationsAsync(forceRefresh: Bool = false) async -> [DiscoveredApp] {
        if !forceRefresh, let cached = cachedApps { return cached }
        let diskApps = await Task.detached(priority: .userInitiated) {
            AppDiscoveryService.performDiskDiscovery()
        }.value
        return finalizeDiscoveredApps(diskApps)
    }

    private static func finalizeDiscoveredApps(_ diskApps: [DiscoveredApp]) -> [DiscoveredApp] {
        installedIdentifiersCache = nil
        var apps = diskApps
        mergeRunningApplications(into: &apps)
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cachedApps = apps
        return apps
    }

    private static func mergeRunningApplications(into apps: inout [DiscoveredApp]) {
        var existingBundleIds = Set(apps.map { $0.bundleId.lowercased() })

        // Include our own accessory app even when Xcode launches it from DerivedData.
        // Keep the disk scan's build-artifact filters intact for other applications.
        if let id = Bundle.main.bundleIdentifier,
           existingBundleIds.insert(id.lowercased()).inserted {
            let name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? "Kaskas"
            apps.append(DiscoveredApp(id: id, name: name, bundleId: id, path: Bundle.main.bundleURL.path))
        }

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let name = app.localizedName, let id = app.bundleIdentifier {
                let path = app.bundleURL?.path ?? ""
                if !path.isEmpty && !AppDiscoveryService.isAllowedAppPath(path) {
                    continue
                }
                let key = id.lowercased()
                if existingBundleIds.insert(key).inserted {
                    apps.append(DiscoveredApp(id: id, name: name, bundleId: id, path: path))
                }
            }
        }
    }

    public func resolveCategory(bundleId: String?, appName: String?) -> AppCategory {
        category(for: resolution(bundleID: bundleId, appName: appName).categoryID) ?? .other
    }

    public func addOrUpdateRule(appIdentifier: String, displayName: String, categoryId: String) {
        let cleanIdentifier = appIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIdentifier.isEmpty else { return }

        // Remove any existing custom rule for this identifier
        customRules.removeAll { $0.appIdentifier.caseInsensitiveCompare(cleanIdentifier) == .orderedSame }

        let newRule = CategoryRule(
            appIdentifier: cleanIdentifier,
            displayName: cleanName.isEmpty ? cleanIdentifier : cleanName,
            categoryId: categoryId,
            isDefault: false
        )
        customRules.append(newRule)
        saveCustomRules()
        didChange()
    }

    public func removeRule(id: UUID) {
        // Check if it's a custom rule
        if customRules.contains(where: { $0.id == id }) {
            customRules.removeAll { $0.id == id }
            saveCustomRules()
            didChange()
            return
        }

        // If it's a default rule, suppress it so it no longer appears
        if let rule = Self.defaultRules.first(where: { $0.id == id }) {
            suppressedDefaultRuleIdentifiers.insert(rule.appIdentifier.lowercased())
            saveSuppressedRules()
            didChange()
        }
    }

    public func suppressAutomaticAssignment(appIdentifier: String) {
        let key = CategoryResolver.normalize(appIdentifier)
        guard !key.isEmpty else { return }
        customRules.removeAll { CategoryResolver.normalize($0.appIdentifier) == key }
        suppressedDefaultRuleIdentifiers.insert(key)
        saveCustomRules()
        saveSuppressedRules()
        didChange()
    }

    private func saveSuppressedRules() {
        defaults.set(Array(suppressedDefaultRuleIdentifiers), forKey: Self.suppressedRulesKey)
    }

    private func loadSuppressedRules() {
        if let saved = defaults.stringArray(forKey: Self.suppressedRulesKey) {
            suppressedDefaultRuleIdentifiers = Set(saved)
        }
    }

    public func resetToDefaults() {
        for category in customCategories { archive(category) }
        customRules.removeAll()
        customCategories.removeAll()
        hiddenBuiltInCategoryIds.removeAll()
        suppressedDefaultRuleIdentifiers.removeAll()
        defaults.removeObject(forKey: StorageKey.customRules)
        defaults.removeObject(forKey: StorageKey.customCategories)
        defaults.removeObject(forKey: Self.hiddenCategoriesKey)
        defaults.removeObject(forKey: Self.suppressedRulesKey)
        didChange()
    }

    // MARK: - Persistence

    private func loadCustomData() {
        if let data = defaults.data(forKey: StorageKey.customRules),
           let rules = try? decoder.decode([CategoryRule].self, from: data) {
            customRules = rules
        }

        if let data = defaults.data(forKey: StorageKey.customCategories),
           let cats = try? decoder.decode([AppCategory].self, from: data) {
            customCategories = cats
        }

        if let data = defaults.data(forKey: StorageKey.archivedCategories),
           let categories = try? decoder.decode([AppCategory].self, from: data) { archivedCategories = categories }
        loadHiddenCategories()
        loadSuppressedRules()
    }

    private func saveCustomRules() {
        if let data = try? encoder.encode(customRules) {
            defaults.set(data, forKey: StorageKey.customRules)
        }
    }

    // MARK: - Default Rules

    public static let mainAppBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "app.kaskas"

    public static let defaultRules: [CategoryRule] = [
        // Productivity
        CategoryRule(appIdentifier: mainAppBundleIdentifier, displayName: "Kaskas", categoryId: "productivity", isDefault: true),

        // Coding
        CategoryRule(appIdentifier: "com.apple.dt.Xcode", displayName: "Xcode", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.todesktop.230313mzl4w4u92", displayName: "Cursor", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.jetbrains.intellij", displayName: "IntelliJ IDEA", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.jetbrains.pycharm", displayName: "PyCharm", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.jetbrains.webstorm", displayName: "WebStorm", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.sublimetext.4", displayName: "Sublime Text", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.Terminal", displayName: "Terminal", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.googlecode.iterm2", displayName: "iTerm2", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.mitchellh.ghostty", displayName: "Ghostty", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "dev.warp.Warp-Stable", displayName: "Warp", categoryId: "coding", isDefault: true),
        CategoryRule(appIdentifier: "com.github.GitHubClient", displayName: "GitHub Desktop", categoryId: "coding", isDefault: true),

        // Design
        CategoryRule(appIdentifier: "com.figma.Desktop", displayName: "Figma", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.bohemiancoding.sketch3", displayName: "Sketch", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.adobe.Photoshop", displayName: "Adobe Photoshop", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.adobe.Illustrator", displayName: "Adobe Illustrator", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.canva.CanvaDesktop", displayName: "Canva", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "org.blenderfoundation.blender", displayName: "Blender", categoryId: "design", isDefault: true),

        // Writing
        CategoryRule(appIdentifier: "md.obsidian", displayName: "Obsidian", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "notion.id", displayName: "Notion", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.Notes", displayName: "Notlar", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.iWork.Pages", displayName: "Pages", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.microsoft.Word", displayName: "Microsoft Word", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "net.shinyfrog.bear", displayName: "Bear", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.TextEdit", displayName: "TextEdit", categoryId: "writing", isDefault: true),

        // Communication
        CategoryRule(appIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.microsoft.teams", displayName: "Microsoft Teams", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.microsoft.teams2", displayName: String(localized: "categories.rule.teamsNew"), categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.hnc.Discord", displayName: "Discord", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "us.zoom.xos", displayName: "Zoom", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.mail", displayName: "Mail", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "ru.keepcoder.Telegram", displayName: "Telegram", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "net.whatsapp.WhatsApp", displayName: "WhatsApp", categoryId: "communication", isDefault: true),

        // Browsing
        CategoryRule(appIdentifier: "com.apple.Safari", displayName: "Safari", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "com.google.Chrome", displayName: "Google Chrome", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "company.thebrowser.Browser", displayName: "Arc", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "org.mozilla.firefox", displayName: "Firefox", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "com.brave.Browser", displayName: "Brave", categoryId: "browsing", isDefault: true),

        // Entertainment
        CategoryRule(appIdentifier: "com.spotify.client", displayName: "Spotify", categoryId: "entertainment", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.Music", displayName: String(localized: "categories.rule.music"), categoryId: "entertainment", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.TV", displayName: "TV", categoryId: "entertainment", isDefault: true)
    ]
}

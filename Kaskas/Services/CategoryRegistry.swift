import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class CategoryRegistry {
    private enum StorageKey {
        static let customRules = "kaskas_category_custom_rules"
        static let customCategories = "kaskas_category_custom_categories"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public private(set) var customRules: [CategoryRule] = []
    public private(set) var customCategories: [AppCategory] = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCustomData()
    }

    // MARK: - Categories

    public var categories: [AppCategory] {
        var result = AppCategory.defaultCategories
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

        // Add defaults if not overridden
        for def in Self.defaultRules {
            let key = def.appIdentifier.lowercased()
            if seenIdentifiers.insert(key).inserted {
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
        if !bundleId.isEmpty, NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil {
            return true
        }
        if NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == bundleId || $0.localizedName == appName
        }) {
            return true
        }
        let searchName = appName.hasSuffix(".app") ? appName : "\(appName).app"
        let standardPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]
        for path in standardPaths {
            let appPath = (path as NSString).appendingPathComponent(searchName)
            if FileManager.default.fileExists(atPath: appPath) {
                return true
            }
        }
        return false
    }

    public static func iconForApp(bundleId: String, appName: String) -> NSImage? {
        if !bundleId.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleId || $0.localizedName == appName
        }) {
            return app.icon
        }
        let searchName = appName.hasSuffix(".app") ? appName : "\(appName).app"
        let standardPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]
        for path in standardPaths {
            let appPath = (path as NSString).appendingPathComponent(searchName)
            if FileManager.default.fileExists(atPath: appPath) {
                return NSWorkspace.shared.icon(forFile: appPath)
            }
        }
        return nil
    }

    public struct DiscoveredApp: Identifiable, Hashable, Sendable {
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

    public static func discoverInstalledApplications() -> [DiscoveredApp] {
        var map: [String: DiscoveredApp] = [:]
        let fm = FileManager.default
        let standardPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]

        for basePath in standardPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: basePath) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let fullPath = (basePath as NSString).appendingPathComponent(item)
                let url = URL(fileURLWithPath: fullPath)
                if let bundle = Bundle(url: url) {
                    let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                        ?? item.replacingOccurrences(of: ".app", with: "")
                    let id = bundle.bundleIdentifier ?? name
                    if map[id.lowercased()] == nil {
                        map[id.lowercased()] = DiscoveredApp(id: id, name: name, bundleId: id, path: fullPath)
                    }
                }
            }
        }

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let name = app.localizedName, let id = app.bundleIdentifier {
                if map[id.lowercased()] == nil {
                    map[id.lowercased()] = DiscoveredApp(id: id, name: name, bundleId: id, path: "")
                }
            }
        }

        return map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func resolveCategory(bundleId: String?, appName: String?) -> AppCategory {
        for rule in allRules {
            if rule.matches(bundleId: bundleId, appName: appName) {
                if let cat = category(for: rule.categoryId) {
                    return cat
                }
            }
        }
        return .other
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
    }

    public func removeRule(id: UUID) {
        customRules.removeAll { $0.id == id }
        saveCustomRules()
    }

    public func resetToDefaults() {
        customRules.removeAll()
        customCategories.removeAll()
        defaults.removeObject(forKey: StorageKey.customRules)
        defaults.removeObject(forKey: StorageKey.customCategories)
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
    }

    private func saveCustomRules() {
        if let data = try? encoder.encode(customRules) {
            defaults.set(data, forKey: StorageKey.customRules)
        }
    }

    // MARK: - Default Rules

    public static let defaultRules: [CategoryRule] = [
        // Yazılım & Kodlama
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

        // Tasarım & Görsel
        CategoryRule(appIdentifier: "com.figma.Desktop", displayName: "Figma", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.bohemiancoding.sketch3", displayName: "Sketch", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.adobe.Photoshop", displayName: "Adobe Photoshop", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.adobe.Illustrator", displayName: "Adobe Illustrator", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "com.canva.CanvaDesktop", displayName: "Canva", categoryId: "design", isDefault: true),
        CategoryRule(appIdentifier: "org.blenderfoundation.blender", displayName: "Blender", categoryId: "design", isDefault: true),

        // Yazı & Notlar
        CategoryRule(appIdentifier: "md.obsidian", displayName: "Obsidian", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "notion.id", displayName: "Notion", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.Notes", displayName: "Notlar", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.iWork.Pages", displayName: "Pages", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.microsoft.Word", displayName: "Microsoft Word", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "net.shinyfrog.bear", displayName: "Bear", categoryId: "writing", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.TextEdit", displayName: "TextEdit", categoryId: "writing", isDefault: true),

        // İletişim & Toplantı
        CategoryRule(appIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.microsoft.teams", displayName: "Microsoft Teams", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.microsoft.teams2", displayName: "Microsoft Teams (Yeni)", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.hnc.Discord", displayName: "Discord", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "us.zoom.xos", displayName: "Zoom", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.mail", displayName: "Mail", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "ru.keepcoder.Telegram", displayName: "Telegram", categoryId: "communication", isDefault: true),
        CategoryRule(appIdentifier: "net.whatsapp.WhatsApp", displayName: "WhatsApp", categoryId: "communication", isDefault: true),

        // Araştırma & Okuma
        CategoryRule(appIdentifier: "com.apple.Safari", displayName: "Safari", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "com.google.Chrome", displayName: "Google Chrome", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "company.thebrowser.Browser", displayName: "Arc", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "org.mozilla.firefox", displayName: "Firefox", categoryId: "browsing", isDefault: true),
        CategoryRule(appIdentifier: "com.brave.Browser", displayName: "Brave", categoryId: "browsing", isDefault: true),

        // Medya & Eğlence
        CategoryRule(appIdentifier: "com.spotify.client", displayName: "Spotify", categoryId: "entertainment", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.Music", displayName: "Müzik", categoryId: "entertainment", isDefault: true),
        CategoryRule(appIdentifier: "com.apple.TV", displayName: "TV", categoryId: "entertainment", isDefault: true)
    ]
}

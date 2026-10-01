import Foundation
import Testing
@testable import Kaskas

@MainActor
struct CategoryRegistryTests {
    @Test
    func resolvesDefaultRulesCorrectly() {
        let suiteName = "test_categories_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let registry = CategoryRegistry(defaults: defaults)

        // Coding
        #expect(registry.resolveCategory(bundleId: "com.apple.dt.Xcode", appName: "Xcode").id == "coding")
        #expect(registry.resolveCategory(bundleId: "com.microsoft.VSCode", appName: "Code").id == "coding")
        #expect(registry.resolveCategory(bundleId: nil, appName: "Ghostty").id == "coding")

        // Design
        #expect(registry.resolveCategory(bundleId: "com.figma.Desktop", appName: "Figma").id == "design")
        #expect(registry.resolveCategory(bundleId: "com.adobe.Photoshop", appName: "Adobe Photoshop").id == "design")

        // Writing
        #expect(registry.resolveCategory(bundleId: "md.obsidian", appName: "Obsidian").id == "writing")
        #expect(registry.resolveCategory(bundleId: "com.apple.Notes", appName: "Notlar").id == "writing")

        // Communication
        #expect(registry.resolveCategory(bundleId: "com.tinyspeck.slackmacgap", appName: "Slack").id == "communication")

        // Browsing
        #expect(registry.resolveCategory(bundleId: "com.apple.Safari", appName: "Safari").id == "browsing")

        // Entertainment
        #expect(registry.resolveCategory(bundleId: "com.spotify.client", appName: "Spotify").id == "entertainment")

        // Unknown defaults to other
        #expect(registry.resolveCategory(bundleId: "com.unknown.randomapp", appName: "RandomApp").id == "other")
    }

    @Test
    func customRuleOverridesDefaultAndRevertsOnDeletion() {
        let suiteName = "test_categories_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let registry = CategoryRegistry(defaults: defaults)

        // Initially Xcode is coding
        #expect(registry.resolveCategory(bundleId: "com.apple.dt.Xcode", appName: "Xcode").id == "coding")

        // Override Xcode to design
        registry.addOrUpdateRule(appIdentifier: "com.apple.dt.Xcode", displayName: "Xcode", categoryId: "design")
        #expect(registry.resolveCategory(bundleId: "com.apple.dt.Xcode", appName: "Xcode").id == "design")

        // Find the custom rule and remove it
        if let customRule = registry.customRules.first(where: { $0.appIdentifier == "com.apple.dt.Xcode" }) {
            registry.removeRule(id: customRule.id)
        }

        // Should revert back to coding
        #expect(registry.resolveCategory(bundleId: "com.apple.dt.Xcode", appName: "Xcode").id == "coding")
    }

    @Test
    func addsAndPersistsCustomAppRule() {
        let suiteName = "test_categories_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let registry1 = CategoryRegistry(defaults: defaults)
        registry1.addOrUpdateRule(appIdentifier: "com.company.mycustomtool", displayName: "My Tool", categoryId: "writing")

        // Verify resolution
        #expect(registry1.resolveCategory(bundleId: "com.company.mycustomtool", appName: "My Tool").id == "writing")

        // Create new instance with same defaults, verify persistence
        let registry2 = CategoryRegistry(defaults: defaults)
        #expect(registry2.resolveCategory(bundleId: "com.company.mycustomtool", appName: "My Tool").id == "writing")
        #expect(registry2.customRules.count == 1)
    }

    @Test
    func resetToDefaultsClearsCustomizations() {
        let suiteName = "test_categories_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let registry = CategoryRegistry(defaults: defaults)
        registry.addOrUpdateRule(appIdentifier: "custom.app.1", displayName: "App 1", categoryId: "coding")
        registry.addOrUpdateRule(appIdentifier: "custom.app.2", displayName: "App 2", categoryId: "design")
        #expect(registry.customRules.count == 2)

        registry.resetToDefaults()
        #expect(registry.customRules.isEmpty)
        #expect(registry.resolveCategory(bundleId: "custom.app.1", appName: "App 1").id == "other")
    }
}

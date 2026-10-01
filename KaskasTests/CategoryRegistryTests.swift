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

    @Test
    func discoversInstalledApplicationsAndCachesResults() async {
        let apps = CategoryRegistry.discoverInstalledApplications(forceRefresh: true)
        #expect(!apps.isEmpty)

        // Verifies common standard macOS app is found
        let hasSafari = apps.contains { $0.bundleId.lowercased() == "com.apple.safari" || $0.name.lowercased() == "safari" }
        #expect(hasSafari)

        // Verifies no trash or build artifacts leak in
        for app in apps {
            #expect(!app.path.contains("/.Trash/"))
            #expect(!app.path.contains("/DerivedData/"))
            #expect(!app.name.isEmpty)
            #expect(!app.bundleId.isEmpty)
        }

        // Test async discovery and caching
        let asyncApps = await CategoryRegistry.discoverInstalledApplicationsAsync()
        #expect(asyncApps.count == apps.count)

        // Test isAppInstalled
        #expect(CategoryRegistry.isAppInstalled(bundleId: "com.apple.Safari", appName: "Safari"))
    }

    @Test
    func defaultCategoryNamesAreSimplifiedWithoutAmpersands() {
        let suiteName = "test_category_names_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let registry = CategoryRegistry(defaults: defaults)
        let names = registry.categories.map(\.name)

        for name in names {
            #expect(!name.contains("&"))
        }

        #expect(registry.category(for: "coding")?.name == "Yazılım")
        #expect(registry.category(for: "design")?.name == "Tasarım")
        #expect(registry.category(for: "writing")?.name == "Yazı")
        #expect(registry.category(for: "communication")?.name == "İletişim")
        #expect(registry.category(for: "browsing")?.name == "İnternet")
        #expect(registry.category(for: "entertainment")?.name == "Eğlence")
        #expect(registry.category(for: "other")?.name == "Diğer")
    }

    @Test
    func addsAndPersistsCustomCategory() {
        let suiteName = "test_custom_categories_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let registry1 = CategoryRegistry(defaults: defaults)
        let created = registry1.addOrUpdateCategory(name: "Borsa", iconName: "chart.bar.xaxis", colorName: "green")
        #expect(!created.isBuiltIn)
        #expect(created.name == "Borsa")
        #expect(registry1.categories.contains { $0.id == created.id })

        // Check persistence
        let registry2 = CategoryRegistry(defaults: defaults)
        let fetched = registry2.category(for: created.id)
        #expect(fetched != nil)
        #expect(fetched?.name == "Borsa")
        #expect(fetched?.colorName == "green")
    }

    @Test
    func removesCustomCategoryAndReassignsRulesToOther() {
        let suiteName = "test_delete_categories_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let registry = CategoryRegistry(defaults: defaults)
        let customCat = registry.addOrUpdateCategory(name: "Ders", iconName: "book.fill", colorName: "purple")

        // Add a rule targeting this custom category
        registry.addOrUpdateRule(appIdentifier: "com.anki.Anki", displayName: "Anki", categoryId: customCat.id)
        #expect(registry.resolveCategory(bundleId: "com.anki.Anki", appName: "Anki").id == customCat.id)

        // Cannot remove fallback "other" category
        registry.removeCategory(id: "other")
        #expect(registry.category(for: "other") != nil)

        // Removing built-in category hides it
        registry.removeCategory(id: "coding")
        #expect(registry.category(for: "coding") == nil)
        #expect(registry.hiddenBuiltInCategoryIds.contains("coding"))

        // Remove custom category
        registry.removeCategory(id: customCat.id)
        #expect(registry.category(for: customCat.id) == nil)

        // The rule should now point to other
        #expect(registry.resolveCategory(bundleId: "com.anki.Anki", appName: "Anki").id == "other")
    }
}

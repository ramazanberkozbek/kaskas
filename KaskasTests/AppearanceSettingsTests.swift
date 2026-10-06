import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Kaskas

struct AppearanceSettingsTests {
    @Test
    func appearanceOptionsMapToExpectedColorSchemesAndNSAppearances() {
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
        #expect(AppAppearance.system.colorScheme == nil)

        #expect(AppAppearance.light.nsAppearance?.name == .aqua)
        #expect(AppAppearance.dark.nsAppearance?.name == .darkAqua)
        #expect(AppAppearance.system.nsAppearance == nil)

        #expect(AppAppearance.light.effectiveColorScheme == .light)
        #expect(AppAppearance.dark.effectiveColorScheme == .dark)
        #expect(AppAppearance.system.effectiveColorScheme == AppAppearance.systemColorScheme)
    }

    @Test
    @MainActor
    func updatingAppearanceAppliesToAppAndSaves() throws {
        let suite = "AppearanceSettingsTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SessionStore(defaults: defaults)
        let controller = SessionController(store: store)

        #expect(controller.configuration.appAppearance == .system)

        var newConfig = controller.configuration
        newConfig.appAppearance = .dark
        controller.updateConfiguration(newConfig)

        #expect(controller.configuration.appAppearance == .dark)
        #expect(controller.effectiveColorScheme == .dark)
        #expect(NSApplication.shared.appearance?.name == .darkAqua)

        newConfig.appAppearance = .light
        controller.updateConfiguration(newConfig)

        #expect(controller.configuration.appAppearance == .light)
        #expect(controller.effectiveColorScheme == .light)
        #expect(NSApplication.shared.appearance?.name == .aqua)

        newConfig.appAppearance = .system
        controller.updateConfiguration(newConfig)

        #expect(controller.configuration.appAppearance == .system)
        #expect(NSApplication.shared.appearance == nil)

        let reloadedStore = SessionStore(defaults: defaults)
        #expect(reloadedStore.loadConfiguration().appAppearance == .system)
    }
}

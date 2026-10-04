import Foundation
import Testing
@testable import Kaskas

struct DeveloperPreferencesTests {
    @Test
    func togglingDeveloperModeUpdatesPreference() {
        let initial = DeveloperPreferences.isEnabled
        defer { DeveloperPreferences.isEnabled = initial }

        DeveloperPreferences.isEnabled = false
        #expect(!DeveloperPreferences.isEnabled)

        let toggled = DeveloperPreferences.toggle()
        #expect(toggled)
        #expect(DeveloperPreferences.isEnabled)

        let toggledBack = DeveloperPreferences.toggle()
        #expect(!toggledBack)
        #expect(!DeveloperPreferences.isEnabled)
    }
}

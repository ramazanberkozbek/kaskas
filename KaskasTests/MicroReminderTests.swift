import AppKit
import Foundation
import Testing
@testable import Kaskas

struct MicroReminderTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private var configuration: FocusConfiguration {
        FocusConfiguration(focusDuration: 3600, microReminderInterval: 300,
                           breakWarningEnabled: false)
    }

    @Test func disabledRemindersLeaveTheBreakTimerRunning() {
        var config = configuration
        config.microRemindersEnabled = false
        var engine = SessionEngine(configuration: config, now: start)
        #expect(engine.session.nextMicroReminderAt == nil)
        #expect(engine.nextEventDate == start.addingTimeInterval(3600))
        #expect(!engine.send(.tick, at: start.addingTimeInterval(300)).contains(.showMicroReminder))
        #expect(engine.send(.tick, at: start.addingTimeInterval(3600))
            .contains(.showBreak(endsAt: start.addingTimeInterval(3900))))
        engine.send(.completeBreak, at: start.addingTimeInterval(3900))
        #expect(engine.session.nextMicroReminderAt == nil)
        engine.resetFocus(at: start.addingTimeInterval(4000))
        #expect(engine.session.nextMicroReminderAt == nil)
    }

    @Test func disablingDismissesAndEnablingSchedulesFromTheChange() {
        var engine = SessionEngine(configuration: configuration, now: start)
        let endsAt = engine.session.endsAt
        var config = configuration
        config.microRemindersEnabled = false
        let effects = engine.send(.updateConfiguration(config), at: start.addingTimeInterval(300))
        #expect(effects.contains(.dismissMicroReminder))
        #expect(effects.contains(.scheduleNextTick(at: endsAt)))
        #expect(engine.session.nextMicroReminderAt == nil)
        #expect(!engine.send(.tick, at: start.addingTimeInterval(600)).contains(.showMicroReminder))
        config.microReminderInterval = 600
        engine.send(.updateConfiguration(config), at: start.addingTimeInterval(600))
        #expect(engine.session.nextMicroReminderAt == nil)
        config.microRemindersEnabled = true
        engine.send(.updateConfiguration(config), at: start.addingTimeInterval(700))
        #expect(engine.session.endsAt == endsAt)
        #expect(engine.session.nextMicroReminderAt == start.addingTimeInterval(1300))
        #expect(engine.send(.tick, at: start.addingTimeInterval(1300)).contains(.showMicroReminder))
    }

    @Test func disabledRemindersStayOffAfterPauseAndRestore() {
        var engine = SessionEngine(configuration: configuration, now: start)
        engine.send(.setManualPause(active: true), at: start.addingTimeInterval(100))
        let savedStateWithPendingReminder = engine.state
        var config = configuration
        config.microRemindersEnabled = false
        engine.send(.updateConfiguration(config), at: start.addingTimeInterval(150))
        #expect(engine.session.nextMicroReminderAt == nil)
        engine.send(.setManualPause(active: false), at: start.addingTimeInterval(200))
        #expect(engine.session.nextMicroReminderAt == nil)
        var restored = SessionEngine(configuration: config, restoredState: savedStateWithPendingReminder,
                                     now: start.addingTimeInterval(200))
        #expect(restored.session.nextMicroReminderAt == nil)
        restored.send(.setManualPause(active: false), at: start.addingTimeInterval(200))
        #expect(restored.session.nextMicroReminderAt == nil)
        #expect(!restored.send(.tick, at: start.addingTimeInterval(500)).contains(.showMicroReminder))
        let activeState = SessionEngine(configuration: configuration, now: start).state
        let activeRestored = SessionEngine(configuration: config, restoredState: activeState, now: start)
        #expect(activeRestored.session.nextMicroReminderAt == nil)
        #expect(activeRestored.nextEventDate == start.addingTimeInterval(3600))
    }

    @Test func changingAppearanceKeepsTheExistingReminderSchedule() {
        var engine = SessionEngine(configuration: configuration, now: start)
        let scheduled = engine.session.nextMicroReminderAt
        var config = configuration
        config.microReminderDisplayMode = .cursorIcon
        let effects = engine.send(.updateConfiguration(config), at: start.addingTimeInterval(100))
        #expect(effects.contains(.dismissMicroReminder))
        #expect(engine.session.nextMicroReminderAt == scheduled)
    }

    @Test func oldPreferencesKeepTheExistingAppearance() throws {
        let config = try JSONDecoder().decode(FocusConfiguration.self, from: Data("{}".utf8))
        #expect(config.microRemindersEnabled)
        #expect(config.microReminderDisplayMode == .mascot)
        #expect(config.microReminderCommitmentMode == .flexible)
    }

    @Test func legacySkippingPreferencesMigrate() throws {
        for (allowed, expected) in [(true, MicroReminderCommitmentMode.flexible), (false, .focused)] {
            let data = Data("{\"microReminderSkippable\":\(allowed)}".utf8)
            let config = try JSONDecoder().decode(FocusConfiguration.self, from: data)
            #expect(config.microReminderCommitmentMode == expected)
        }
    }

    @Test func removedBalancedModeMigratesToFlexible() throws {
        let data = Data("{\"microReminderCommitmentMode\":\"balanced\"}".utf8)
        let config = try JSONDecoder().decode(FocusConfiguration.self, from: data)
        #expect(config.microReminderCommitmentMode == .flexible)
        #expect(MicroReminderCommitmentMode.allCases == [.flexible, .focused])
    }

    @Test func skippingPreferenceSurvivesReopening() throws {
        let suite = "MicroReminderTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var config = FocusConfiguration()
        config.microReminderCommitmentMode = .focused
        SessionStore(defaults: defaults).save(configuration: config)
        #expect(SessionStore(defaults: defaults).loadConfiguration().microReminderCommitmentMode == .focused)
    }

    @MainActor @Test func mascotCanBeDismissedOnlyWhenSkippingIsAllowed() throws {
        let suite = "MicroReminderTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = MicroReminderPresenter(defaults: defaults)
        defer { presenter.dismiss() }
        presenter.show(mascot: .flame, color: .white, commitmentMode: .focused)
        let strictPanel = try #require(presenter.panel)
        #expect(!strictPanel.canBecomeKey)
        strictPanel.cancelOperation(nil)
        #expect(presenter.panel != nil)

        presenter.show(mascot: .flame, color: .white, commitmentMode: .flexible)
        let skippablePanel = try #require(presenter.panel)
        #expect(skippablePanel.canBecomeKey)
        skippablePanel.cancelOperation(nil)
        #expect(presenter.panel == nil)
        #expect(!skippablePanel.isVisible)
    }

    @MainActor @Test func escapeHintAppearsOnceAndSurvivesReopening() throws {
        let suite = "MicroReminderTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = MicroReminderPresenter(defaults: defaults)
        defer { presenter.dismiss() }
        #expect(FocusConfiguration().microReminderCommitmentMode.allowsSkipping)
        presenter.show(mascot: .flame, color: .white, commitmentMode: .focused)
        #expect(!presenter.showsEscapeHint)
        presenter.show(displayMode: .cursorIcon, mascot: .flame, color: .white)
        #expect(!presenter.showsEscapeHint)
        presenter.show(mascot: .flame, color: .white, isPreview: true)
        #expect(presenter.showsEscapeHint)
        presenter.show(mascot: .flame, color: .white)
        #expect(!presenter.showsEscapeHint)
        presenter.dismiss()
        let reopened = MicroReminderPresenter(defaults: defaults)
        defer { reopened.dismiss() }
        reopened.show(mascot: .flame, color: .white)
        #expect(!reopened.showsEscapeHint)
        let panel = try #require(reopened.panel)
        panel.cancelOperation(nil)
        #expect(reopened.panel == nil)
    }

    @MainActor @Test func mouseClickSkipsOnlyWhenAllowed() throws {
        let suite = "MicroReminderTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = MicroReminderPresenter(defaults: defaults)
        defer { presenter.dismiss() }
        let click = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1))
        presenter.show(mascot: .flame, color: .white, commitmentMode: .focused)
        presenter.panel?.mouseDown(with: click)
        #expect(presenter.panel != nil)
        presenter.show(mascot: .flame, color: .white)
        presenter.panel?.mouseDown(with: click)
        #expect(presenter.panel == nil)
    }

    @MainActor @Test func cursorModeUsesASmallClickThroughPanelAndDismissesOnModeChange() throws {
        let suite = "MicroReminderTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = MicroReminderPresenter(defaults: defaults)
        defer { presenter.dismiss() }
        presenter.show(displayMode: .cursorIcon, mascot: .glasses, color: .mint, isPreview: true)
        let panel = try #require(presenter.panel)
        #expect(panel.frame.size == CursorMicroReminderView.panelSize)
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.isOpaque)
        #expect(!panel.canBecomeKey)
        presenter.dismissPreview()
        #expect(presenter.panel == nil)
        #expect(!panel.isVisible)
        presenter.show(displayMode: .mascot, mascot: .flame, color: .white, isPreview: true)
        let fullscreen = try #require(presenter.panel)
        #expect(fullscreen.frame.width > CursorMicroReminderView.panelSize.width)
        presenter.show(displayMode: .cursorIcon, mascot: .flame, color: .white)
        #expect(!fullscreen.isVisible)
        #expect(presenter.panel?.frame.size == CursorMicroReminderView.panelSize)
        presenter.dismissPreview()
        #expect(presenter.panel != nil)
    }

    @MainActor @Test func microReminderSkipLabelRespectsLocale() throws {
        #expect(AppLanguage.localizedString("reminder.skip", locale: Locale(identifier: "en")) == "Skip")
        #expect(AppLanguage.localizedString("reminder.skip", locale: Locale(identifier: "tr")) == "Geç")
        #expect(AppLanguage.localizedString("reminder.title", locale: Locale(identifier: "en")) == "Take a breath")
        #expect(AppLanguage.localizedString("reminder.title", locale: Locale(identifier: "tr")) == "Kısa bir nefes")
    }
}

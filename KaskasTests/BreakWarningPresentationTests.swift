import AppKit
import SwiftUI
import Testing
@testable import Kaskas

@MainActor
struct BreakWarningPresentationTests {
    @Test func typingAndRestartUpdateTheExistingWarningWindow() throws {
        let presenter = BreakWarningPresenter()
        defer { presenter.dismiss() }
        let initialEnd = Date().addingTimeInterval(20)
        presenter.show(endsAt: initialEnd, leadTime: 20, position: .center,
                       onStart: {}, onPostpone: { _ in }, onSkip: {})
        let panel = try #require(presenter.panel)
        let host = try #require(panel.contentView as? NSHostingView<BreakWarningView>)
        let originalFrame = panel.frame
        let originalWindowNumber = panel.windowNumber

        presenter.show(endsAt: initialEnd, leadTime: 20, position: .center, pausedRemaining: 7,
                       onStart: {}, onPostpone: { _ in }, onSkip: {})
        #expect(presenter.panel === panel)
        #expect(panel.contentView === host)
        #expect(host.rootView.pausedRemaining == 7)
        #expect(panel.isVisible)

        let restartedEnd = Date().addingTimeInterval(20)
        presenter.show(endsAt: restartedEnd, leadTime: 20, position: .center,
                       onStart: {}, onPostpone: { _ in }, onSkip: {})
        #expect(presenter.panel === panel)
        #expect(panel.contentView === host)
        #expect(panel.windowNumber == originalWindowNumber)
        #expect(panel.frame == originalFrame)
        #expect(panel.animationBehavior == .none)
        #expect(host.rootView.pausedRemaining == nil)
        #expect(host.rootView.endsAt == restartedEnd)
    }

    @Test func cursorBadgesShareAWindowAndLeftAnchor() throws {
        let presenter = CursorBreakCountdownPresenter()
        defer { presenter.dismiss() }
        presenter.show(endsAt: Date().addingTimeInterval(20), leadTime: 20)
        let panel = try #require(presenter.panel)
        let host = panel.contentView
        let countdownSize = panel.frame.size
        presenter.showTypingPause()
        #expect(presenter.panel === panel)
        #expect(panel.contentView === host)
        #expect(panel.frame.size == CursorTypingPauseView.panelSize)
        presenter.showMeetingPause()
        #expect(presenter.panel === panel)
        #expect(panel.contentView === host)
        #expect(panel.animationBehavior == .none)

        let pointer = NSPoint(x: 700, y: 400)
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        for size in [countdownSize, CursorTypingPauseView.panelSize, CursorMeetingPauseView.panelSize] {
            let origin = CursorBreakCountdownPresenter.origin(beside: pointer, size: size, screenFrame: screen)
            #expect(origin.x + size.width == pointer.x - 10)
            #expect(origin.y + size.height / 2 == pointer.y - 6)
            let edgeOrigin = CursorBreakCountdownPresenter.origin(beside: .zero, size: size, screenFrame: screen)
            #expect(screen.contains(NSRect(origin: edgeOrigin, size: size)))
        }
    }

    @Test func oldDismissalDoesNotCloseTypingOrRestartedWarnings() async throws {
        let presenter = BreakWarningPresenter()
        defer { presenter.dismiss() }
        let initialEnd = Date().addingTimeInterval(0.5)
        presenter.show(endsAt: initialEnd, leadTime: 20, position: .center,
                       onStart: {}, onPostpone: { _ in }, onSkip: {})
        let panel = try #require(presenter.panel)
        presenter.show(endsAt: initialEnd, leadTime: 20, position: .center, pausedRemaining: 1,
                       onStart: {}, onPostpone: { _ in }, onSkip: {})
        try await Task.sleep(for: .seconds(0.7))
        #expect(presenter.panel === panel)
        #expect(panel.isVisible)
        presenter.show(endsAt: Date().addingTimeInterval(0.2), leadTime: 20, position: .center,
                       onStart: {}, onPostpone: { _ in }, onSkip: {})
        try await Task.sleep(for: .seconds(0.4))
        #expect(presenter.panel == nil)
    }
}

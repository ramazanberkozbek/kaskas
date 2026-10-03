import Combine
import SwiftUI

@main
struct KaskasApp: App {
    @NSApplicationDelegateAdaptor(KaskasAppDelegate.self) private var appDelegate

    init() {
        SingleInstanceCoordinator.shared.enforceSingleInstance()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: appDelegate.sessionController)
                .environment(\.locale, appDelegate.sessionController.locale)
                .id(appDelegate.sessionController.configuration.appLanguage)
        } label: {
            MenuBarStatusLabel(controller: appDelegate.sessionController)
                .environment(\.locale, appDelegate.sessionController.locale)
                .id(appDelegate.sessionController.configuration.appLanguage)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusLabel: View {
    let controller: SessionController

    @State private var now = Date.now

    private let clock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        let snapshot = controller.sessionSnapshot
        let remaining = snapshot.status.isPaused
            ? snapshot.remaining
            : max(0, snapshot.endsAt.timeIntervalSince(now))
        let displayMode = controller.configuration.menuBarDisplayMode

        HStack(spacing: 4) {
            if displayMode != .timerOnly {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }

            if displayMode != .iconOnly {
                Text(MenuBarDurationFormatter.string(for: remaining, locale: controller.locale))
                    .monospacedDigit()
            }
        }
        .onReceive(clock) { now = $0 }
        .onChange(of: controller.sessionSnapshot) { _, _ in now = .now }
    }
}

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
        } label: {
            MenuBarStatusLabel(controller: appDelegate.sessionController)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusLabel: View {
    let controller: SessionController

    @State private var now = Date.now

    private let clock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = controller.snapshot(at: now).remaining
        let displayMode = controller.configuration.menuBarDisplayMode

        HStack(spacing: 4) {
            if displayMode != .timerOnly {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }

            if displayMode != .iconOnly {
                Text(MenuBarDurationFormatter.string(for: remaining))
                    .monospacedDigit()
            }
        }
        .onReceive(clock) { now = $0 }
    }
}

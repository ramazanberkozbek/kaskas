import Combine
import SwiftUI

@main
struct KaskasApp: App {
    @NSApplicationDelegateAdaptor(KaskasAppDelegate.self) private var appDelegate

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

        HStack(spacing: 4) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)

            Text(remaining < 60 ? "<1d" : "\(Int(ceil(remaining / 60)))d")
                .monospacedDigit()
        }
        .onReceive(clock) { now = $0 }
    }
}

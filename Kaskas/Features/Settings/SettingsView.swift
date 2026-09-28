import AppKit
import SwiftUI

struct SettingsView: View {
    let controller: SessionController

    @State private var selection: SettingsPane = .focus
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(
                min: 180, ideal: 200, max: 260
            )
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 6)
            }
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .background(SettingsWindowChrome(colorScheme: colorScheme))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .focus:
            FocusSettingsView(controller: controller)
        case .wellness:
            WellnessSettingsView(controller: controller)
        case .alerts:
            AlertsSettingsView(controller: controller)
        case .statistics:
            StatisticsView(controller: controller)
        case .general:
            GeneralSettingsView(controller: controller)
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case focus
    case wellness
    case alerts
    case statistics
    case general

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .focus: "settings.sidebar.focus"
        case .wellness: "settings.sidebar.wellness"
        case .alerts: "settings.sidebar.notifications"
        case .statistics: "settings.sidebar.statistics"
        case .general: "settings.sidebar.general"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "leaf"
        case .wellness: "waveform.path.ecg"
        case .alerts: "bell.badge"
        case .statistics: "chart.bar.xaxis"
        case .general: "gearshape"
        }
    }
}

private struct SettingsPlaceholderView: View {
    let pane: SettingsPane

    var body: some View {
        ContentUnavailableView {
            Label(pane.title, systemImage: pane.systemImage)
        } description: {
            Text("settings.comingSoon")
        }
    }
}

// MARK: - Window Chrome

/// Configures the Settings window so the title bar is transparent and the
/// traffic lights sit inline with the sidebar, matching the SpacedRepetition
/// project's MacWindowChromeConfigurator approach.
private struct SettingsWindowChrome: NSViewRepresentable {
    var colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(window: nsView.window)
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = colorScheme == .dark
            ? NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
            : .windowBackgroundColor
    }
}

import AppKit
import SwiftUI

struct SettingsView: View {
    let controller: SessionController

    @State private var selection: SettingsPane = .dashboard
    @State private var focusSubpage: FocusSubpage?
    @State private var navigationTrace = SettingsNavigationTrace()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: paneSelection) { pane in
                Group {
                    if pane == .focus, selection == .focus, focusSubpage != nil {
                        // Reselecting Focus returns from its design subpage.
                        Button { focusSubpage = nil } label: { sidebarLabel(pane) }
                            .buttonStyle(.plain)
                    } else {
                        sidebarLabel(pane)
                    }
                }
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
        .environment(\.locale, controller.locale)
        .id(controller.configuration.appLanguage)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .dashboard:
            DashboardView(controller: controller)
        case .focus:
            FocusSettingsView(controller: controller, subpage: $focusSubpage)
                .onAppear { navigationTrace.appeared(SettingsPane.focus.rawValue) }
        case .alerts:
            AlertsSettingsView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.alerts.rawValue) }
        case .statistics:
            StatisticsView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.statistics.rawValue) }
        case .categories:
            CategorySettingsView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.categories.rawValue) }
        case .general:
            GeneralSettingsView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.general.rawValue) }
        }
    }

    private var paneSelection: Binding<SettingsPane> {
        Binding {
            selection
        } set: { pane in
            if pane == .focus { focusSubpage = nil }
            guard pane != selection else { return }
            navigationTrace.selected(pane.rawValue)
            selection = pane
        }
    }

    private func sidebarLabel(_ pane: SettingsPane) -> some View {
        Label(pane.title, systemImage: pane.systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case dashboard
    case focus
    case alerts
    case statistics
    case categories
    case general

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "settings.sidebar.dashboard"
        case .focus: "settings.sidebar.focus"
        case .alerts: "settings.sidebar.notifications"
        case .statistics: "settings.sidebar.statistics"
        case .categories: "settings.sidebar.categories"
        case .general: "settings.sidebar.general"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .focus: "leaf"
        case .alerts: "bell.badge"
        case .statistics: "chart.bar.xaxis"
        case .categories: "square.grid.3x3.fill"
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
        if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
        if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
        let backgroundColor = colorScheme == .dark
            ? NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
            : NSColor.windowBackgroundColor
        if window.backgroundColor != backgroundColor { window.backgroundColor = backgroundColor }
    }
}

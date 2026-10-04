import AppKit
import SwiftUI

struct SettingsView: View {
    let controller: SessionController

    @State private var selection: SettingsPane = .dashboard
    @State private var hoveredPane: SettingsPane?
    @State private var navigationTrace = SettingsNavigationTrace()
    @AppStorage(DeveloperPreferences.Key.isEnabled) private var isDeveloperModeEnabled = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            List(availablePanes, selection: paneSelection) { pane in
                sidebarLabel(pane)
                    .tag(pane)
                    .listRowBackground(
                        Color.clear
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06))
                                    .padding(.horizontal, 10)
                                    .opacity(hoveredPane == pane && selection != pane ? 1 : 0)
                            }
                            .contentShape(Rectangle())
                            .onHover { isHovered in
                                if isHovered {
                                    hoveredPane = pane
                                } else if hoveredPane == pane {
                                    hoveredPane = nil
                                }
                            }
                            .animation(.easeInOut(duration: 0.15), value: hoveredPane)
                    )
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .navigationSplitViewColumnWidth(
                min: 180, ideal: 200, max: 260
            )
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 6)
            }
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollIndicators(.hidden)
                .toolbar(removing: .title)
                // The detail has no toolbar items; let its scrolling content
                // use that space while the sidebar keeps its window controls.
                .ignoresSafeArea(.container, edges: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .scrollIndicators(.hidden)
        .background(SettingsWindowChrome(colorScheme: colorScheme))
        .background {
            Button("") {
                withAnimation {
                    isDeveloperModeEnabled.toggle()
                    if isDeveloperModeEnabled {
                        selection = .developer
                    } else if selection == .developer {
                        selection = .general
                    }
                }
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            .opacity(0)
            .allowsHitTesting(false)
        }
        .environment(\.locale, controller.locale)
        .id(controller.configuration.appLanguage)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .dashboard:
            DashboardView(controller: controller)
        case .focus:
            FocusSettingsView(controller: controller)
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
        case .developer:
            DeveloperSettingsView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.developer.rawValue) }
        }
    }

    private var availablePanes: [SettingsPane] {
        SettingsPane.allCases.filter { pane in
            if pane == .developer {
                return isDeveloperModeEnabled
            }
            return true
        }
    }

    private var paneSelection: Binding<SettingsPane> {
        Binding {
            selection
        } set: { pane in
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
    case developer

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "settings.sidebar.dashboard"
        case .focus: "settings.sidebar.focus"
        case .alerts: "settings.sidebar.notifications"
        case .statistics: "settings.sidebar.statistics"
        case .categories: "settings.sidebar.categories"
        case .general: "settings.sidebar.general"
        case .developer: "settings.sidebar.developer"
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
        case .developer: "hammer.fill"
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

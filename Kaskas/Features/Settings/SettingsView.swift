import AppKit
import SwiftUI

struct SettingsView: View {
    let controller: SessionController

    @State private var selection: SettingsPane
    @State private var hoveredPane: SettingsPane?
    @State private var navigationTrace = SettingsNavigationTrace()
    @State private var statisticsState = StatisticsViewState()
    @AppStorage(DeveloperPreferences.Key.isEnabled) private var isDeveloperModeEnabled = false

    init(controller: SessionController, initialPane: SettingsPane = .dashboard) {
        self.controller = controller
        _selection = State(initialValue: controller.targetSettingsPane ?? initialPane)
    }

    private var effectiveColorScheme: ColorScheme {
        controller.effectiveColorScheme
    }

    var body: some View {
        NavigationSplitView {
            List(selection: paneSelection) {
                ForEach(sidebarPanes) { pane in
                    sidebarRow(pane)
                }
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
        .background(SettingsWindowChrome(colorScheme: effectiveColorScheme, appearance: controller.configuration.appAppearance))
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
        .onChange(of: controller.targetSettingsPane, initial: true) { _, newPane in
            if let newPane {
                selection = newPane
                controller.targetSettingsPane = nil
            }
        }
        .environment(\.locale, controller.locale)
        .environment(\.colorScheme, effectiveColorScheme)
        .preferredColorScheme(effectiveColorScheme)
        .id(controller.configuration.appLanguage)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .dashboard:
            DashboardView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.dashboard.rawValue) }
        case .focus:
            FocusSettingsView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.focus.rawValue) }
        case .alerts:
            AlertsSettingsView(controller: controller)
                .onAppear { navigationTrace.appeared(SettingsPane.alerts.rawValue) }
        case .statistics:
            StatisticsView(controller: controller, state: statisticsState)
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

    private var sidebarPanes: [SettingsPane] {
        let panes: [SettingsPane] = [.dashboard, .focus, .alerts, .statistics, .categories, .general]
        return isDeveloperModeEnabled ? panes + [.developer] : panes
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

    private func sidebarRow(_ pane: SettingsPane) -> some View {
        sidebarLabel(pane)
            .tag(pane)
            .listRowBackground(
                Color.clear
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(effectiveColorScheme == .dark ? 0.09 : 0.06))
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

    private func sidebarLabel(_ pane: SettingsPane) -> some View {
        HStack(spacing: 9) {
            Image(systemName: pane.systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(selection == pane ? Color.white : pane.iconColor)
                .frame(width: 20, height: 20)

            Text(pane.title)
                .font(.system(size: 13, weight: .regular))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
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
        case .categories: "square.grid.3x3"
        case .general: "gearshape"
        case .developer: "hammer"
        }
    }

    var iconColor: Color {
        switch self {
        case .dashboard:
            Color(red: 0.33, green: 0.54, blue: 0.86)
        case .focus:
            Color(red: 0.39, green: 0.70, blue: 0.40)
        case .alerts:
            Color(red: 0.89, green: 0.40, blue: 0.41)
        case .statistics:
            Color(red: 0.89, green: 0.56, blue: 0.32)
        case .categories:
            Color(red: 0.65, green: 0.49, blue: 0.82)
        case .general, .developer:
            Color(nsColor: .systemGray)
        }
    }
}

// MARK: - Window Chrome

/// Configures the Settings window so the title bar is transparent and the
/// traffic lights sit inline with the sidebar.
private struct SettingsWindowChrome: NSViewRepresentable {
    var colorScheme: ColorScheme
    var appearance: AppAppearance

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
        let targetAppearance = appearance.nsAppearance
        if window.appearance != targetAppearance {
            window.appearance = targetAppearance
        }
        let backgroundColor = colorScheme == .dark
            ? NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
            : NSColor.windowBackgroundColor
        if window.backgroundColor != backgroundColor { window.backgroundColor = backgroundColor }
    }
}

import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    let controller: SessionController
    @AppStorage(DeveloperPreferences.Key.isEnabled) private var isDeveloperModeEnabled = false
    @State private var versionClickCount = 0

    var body: some View {
        Form {
            Section {
                AppearanceSettingsPicker(selection: appAppearance)
                    .settingsFormRow()
            } header: {
                VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                    SettingsPaneHeader(title: "settings.sidebar.general")
                    sectionHeader("settings.theme.section")
                }
                .settingsFormSectionHeader()
            }
            Section {
                Group {
                    LabeledContent("settings.language.title") {
                        SettingsMenuPicker(
                            title: "settings.language.title",
                            selection: appLanguage,
                            selectedLabel: Text(controller.configuration.appLanguage.displayName)
                        ) {
                            ForEach(AppLanguage.allCases) { language in
                                languageOptionRow(for: language).tag(language)
                            }
                        }
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.language.section")
                    .settingsFormSectionHeader()
            }
            Section {
                Group {
                    Toggle(isOn: launchAtLogin) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("settings.startup.enabled")
                            Text("settings.startup.description")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if controller.launchAtLogin.requiresApproval {
                        Text("settings.startup.approval")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("settings.startup.openSystemSettings") {
                            controller.launchAtLogin.openSystemSettings()
                        }
                    }
                    if controller.launchAtLogin.updateFailed {
                        Text("settings.startup.error")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.startup.section")
                    .settingsFormSectionHeader()
            }
            Section {
                Group {
                    Toggle(isOn: showInDock) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("settings.dock.enabled")
                            Text("settings.dock.description")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.dock.section")
                    .settingsFormSectionHeader()
            }
            MenuBarAppearanceSettingsView(controller: controller)
            Section {
                ProtectionSettingsCardsView(controller: controller)
                    .settingsFormRow()
                    .padding(.vertical, 6)
            } header: {
                sectionHeader("settings.protection.section")
                    .settingsFormSectionHeader()
            }
            Section {
                Group {
                    IdleDetectionTriggerRow(
                        isEnabled: idleDetectionEnabled,
                        promptEnabled: idlePromptEnabled
                    )
                    if controller.configuration.idleDetectionEnabled {
                        SettingsDurationRow(
                            title: "settings.idle.threshold",
                            subtitle: "settings.idle.threshold.description",
                            selection: idleThreshold,
                            options: [1, 3, 5, 10].map { TimeInterval($0 * 60) }
                        )
                    }
                }
                .settingsFormRow()
            } header: {
                sectionHeader("settings.idle.section")
                    .settingsFormSectionHeader()
            } footer: {
                HStack {
                    Text(appVersionText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .settingsFormSectionHeader()
                .padding(.top, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    versionClickCount += 1
                    if versionClickCount >= 5 {
                        versionClickCount = 0
                        withAnimation {
                            isDeveloperModeEnabled.toggle()
                        }
                    }
                }
            }
        }
        .settingsGroupedFormLayout()
        .scrollIndicators(.hidden)
        .onAppear { controller.launchAtLogin.refresh() }
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Kaskas v\(version)"
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    private var appAppearance: Binding<AppAppearance> {
        Binding {
            controller.configuration.appAppearance
        } set: { appearance in
            var configuration = controller.configuration
            configuration.appAppearance = appearance
            controller.updateConfiguration(configuration)
        }
    }

    private var appLanguage: Binding<AppLanguage> {
        Binding {
            controller.configuration.appLanguage
        } set: { language in
            var configuration = controller.configuration
            configuration.appLanguage = language
            controller.updateConfiguration(configuration)
        }
    }

    private func languageOptionRow(for language: AppLanguage) -> some View {
        Label {
            Text(language.displayName)
        } icon: {
            languageFlagImage(for: language.rawValue)
                .renderingMode(.original)
        }
    }

    private var showInDock: Binding<Bool> {
        Binding {
            controller.configuration.showInDock
        } set: { enabled in
            var configuration = controller.configuration
            configuration.showInDock = enabled
            controller.updateConfiguration(configuration)
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding {
            controller.launchAtLogin.isEnabled
        } set: { enabled in
            controller.launchAtLogin.setEnabled(enabled)
        }
    }

    private var idleDetectionEnabled: Binding<Bool> {
        Binding {
            controller.configuration.idleDetectionEnabled
        } set: { enabled in
            var configuration = controller.configuration
            configuration.idleDetectionEnabled = enabled
            controller.updateConfiguration(configuration)
        }
    }

    private var idleThreshold: Binding<TimeInterval> {
        Binding {
            controller.configuration.idleThreshold
        } set: { duration in
            var configuration = controller.configuration
            configuration.idleThreshold = duration
            controller.updateConfiguration(configuration)
        }
    }

    private var idlePromptEnabled: Binding<Bool> {
        Binding {
            controller.configuration.idlePromptEnabled
        } set: { enabled in
            var configuration = controller.configuration
            configuration.idlePromptEnabled = enabled
            controller.updateConfiguration(configuration)
        }
    }
}

// MARK: - Idle Detection Row & Hover Preview

private struct IdleDetectionTriggerRow: View {
    @Binding var isEnabled: Bool
    @Binding var promptEnabled: Bool
    @State private var showsPreview = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("settings.idle.enabled")
                Text("settings.idle.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            notificationButton

            Rectangle()
                .fill(.primary.opacity(0.10))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 2)

            Toggle("settings.idle.enabled", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var notificationButton: some View {
        Button {
            promptEnabled.toggle()
            showsPreview = promptEnabled && isEnabled
        } label: {
            HStack(spacing: 5) {
                Image(systemName: promptEnabled ? "bell.fill" : "bell.slash")
                    .font(.system(size: 10, weight: .semibold))
                Text(promptEnabled ? "settings.protection.notification.on" : "settings.protection.notification.off")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(promptEnabled ? Color.accentColor : .secondary)
            .frame(minWidth: 48, minHeight: 28)
            .padding(.horizontal, 7)
            .background(promptEnabled ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(promptEnabled ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel("settings.idle.prompt.enabled")
        .accessibilityValue(Text(promptEnabled ? "settings.protection.notification.on" : "settings.protection.notification.off"))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) { showsPreview = hovering && isEnabled }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { showsPreview = false }
        }
        .background(IdlePromptHoverPreview(isPresented: showsPreview, promptEnabled: promptEnabled))
    }
}

private struct IdlePromptHoverPreview: NSViewRepresentable {
    let isPresented: Bool
    let promptEnabled: Bool

    func makeNSView(context: Context) -> IdlePromptPreviewAnchor { IdlePromptPreviewAnchor() }

    func updateNSView(_ view: IdlePromptPreviewAnchor, context: Context) {
        view.update(isPresented: isPresented, promptEnabled: promptEnabled)
    }

    static func dismantleNSView(_ view: IdlePromptPreviewAnchor, coordinator: ()) { view.dismiss() }
}

private final class IdlePromptPreviewAnchor: NSView {
    private var panel: NSPanel?
    private var presented = false
    private var promptEnabled = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(isPresented: Bool, promptEnabled: Bool) {
        presented = isPresented
        self.promptEnabled = promptEnabled
        guard isPresented else { dismiss(); return }
        showIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { dismiss() } else if presented { showIfNeeded() }
    }

    override func layout() {
        super.layout()
        positionPanel()
    }

    private func showIfNeeded() {
        guard let window else { return }
        if let panel {
            (panel.contentView as? NSHostingView<IdlePromptNotificationPreview>)?.rootView =
                IdlePromptNotificationPreview(promptEnabled: promptEnabled)
            positionPanel()
            return
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 294, height: 184),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: IdlePromptNotificationPreview(promptEnabled: promptEnabled))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        self.panel = panel
        window.addChildWindow(panel, ordered: .above)
        positionPanel()
        panel.orderFront(nil)
    }

    private func positionPanel() {
        guard let panel, let window, let screen = window.screen else { return }
        let anchor = window.convertToScreen(convert(bounds, to: nil))
        let area = screen.visibleFrame
        let size = panel.frame.size
        let x = min(max(anchor.maxX - size.width, area.minX), area.maxX - size.width)
        let above = anchor.maxY + 8
        let y = above + size.height <= area.maxY ? above : max(area.minY, anchor.minY - size.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func dismiss() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
    }
}

private struct IdlePromptNotificationPreview: View {
    let promptEnabled: Bool
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IdlePromptCardPreview(promptEnabled: promptEnabled)
                .frame(width: 270)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("settings.idle.prompt.previewCaption")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) { appeared = true }
        }
    }
}

private struct IdlePromptCardPreview: View {
    let promptEnabled: Bool
    @State private var wallpaper = DesktopWallpaperPreview.protection

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = wallpaper.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.30, blue: 0.50), Color(red: 0.42, green: 0.30, blue: 0.44)],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                }
                Color.black.opacity(0.18)

                if promptEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(red: 1, green: 0.69, blue: 0.2))
                                .frame(width: 26, height: 26)
                                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("idle.title")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)

                                Text(String(format: String(localized: "idle.question"), 3))
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 5) {
                            Text("idle.accept")
                                .font(.system(size: 8.5, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.25), in: Capsule())
                                .foregroundStyle(.white)

                            Text("idle.decline")
                                .font(.system(size: 8.5, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .overlay { Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5) }
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(9)
                    .frame(width: 246)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(Color(red: 1, green: 0.69, blue: 0.2).opacity(0.4), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("settings.protection.notification.off")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .frame(height: 130)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await wallpaper.load() }
    }
}

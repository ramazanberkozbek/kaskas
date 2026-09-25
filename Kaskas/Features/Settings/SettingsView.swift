import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
        case .smartPause:
            SettingsPlaceholderView(pane: .smartPause)
        case .alerts:
            SettingsPlaceholderView(pane: .alerts)
        case .statistics:
            SettingsPlaceholderView(pane: .statistics)
        case .general:
            GeneralSettingsView(controller: controller)
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case focus
    case wellness
    case smartPause
    case alerts
    case statistics
    case general

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .focus: "settings.sidebar.focus"
        case .wellness: "settings.sidebar.wellness"
        case .smartPause: "settings.sidebar.smartPause"
        case .alerts: "settings.sidebar.alerts"
        case .statistics: "settings.sidebar.statistics"
        case .general: "settings.sidebar.general"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "leaf"
        case .wellness: "waveform.path.ecg"
        case .smartPause: "pause.circle"
        case .alerts: "bell.badge"
        case .statistics: "chart.bar.xaxis"
        case .general: "gearshape"
        }
    }
}

private struct FocusSettingsView: View {
    let controller: SessionController
    @State private var showingDesign = false
    @State private var showingMicroReminderDesign = false

    private let focusDurations: [TimeInterval] = [10, 15, 20, 30, 45, 60, 90].map { $0 * 60 }
    private let breakDurations: [TimeInterval] = [1, 3, 5, 10, 15].map { $0 * 60 }
    private let snoozeDurations: [TimeInterval] = [3, 5, 10, 15].map { $0 * 60 }

    var body: some View {
        if showingDesign {
            FocusDesignView(controller: controller) {
                showingDesign = false
            }
        } else if showingMicroReminderDesign {
            MicroReminderDesignView(controller: controller) {
                showingMicroReminderDesign = false
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.schedule.title")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            SettingsDurationRow(
                                title: "settings.focusDuration",
                                subtitle: "settings.focusDuration.description",
                                selection: binding(for: \FocusConfiguration.focusDuration),
                                options: focusDurations
                            )

                            Divider().padding(.horizontal, 16)

                            SettingsDurationRow(
                                title: "settings.breakDuration",
                                subtitle: "settings.breakDuration.description",
                                selection: binding(for: \FocusConfiguration.breakDuration),
                                options: breakDurations
                            )

                            Divider().padding(.horizontal, 16)

                            SettingsDurationRow(
                                title: "settings.snoozeDuration",
                                subtitle: "settings.snoozeDuration.description",
                                selection: binding(for: \FocusConfiguration.snoozeDuration),
                                options: snoozeDurations
                            )
                        }
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }

                        Text("settings.nextCycle.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        showingDesign = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "paintpalette")
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("settings.focusDesign.title")
                                    .font(.body.weight(.medium))
                                Text("settings.focusDesign.description")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        showingMicroReminderDesign = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("settings.microReminderDesign.title")
                                    .font(.body.weight(.medium))
                                Text("settings.microReminderDesign.description")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
    }

    private func binding(
        for keyPath: WritableKeyPath<FocusConfiguration, TimeInterval>
    ) -> Binding<TimeInterval> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { newValue in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = newValue
            controller.updateConfiguration(configuration)
        }
    }
}

private struct MicroReminderDesignView: View {
    let controller: SessionController
    let onBack: () -> Void
    @State private var showingMascotPicker = false

    private let reminderIntervals: [TimeInterval] = [5, 10, 15, 20, 25, 30].map { $0 * 60 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button(action: onBack) {
                    Label("settings.sidebar.focus", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 7) {
                    Text("settings.microReminderDesign.title")
                        .font(.system(size: 28, weight: .bold))
                    Text("settings.microReminderDesign.description")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.microReminderDesign.sectionTitle")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                        Text("settings.microReminderDesign.sectionDescription")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        ZStack {
                            MicroReminderArtwork()

                            MicroReminderMascotView(
                                mascot: controller.configuration.microReminderMascot,
                                color: controller.configuration.microReminderColor,
                                size: 116,
                                animated: false
                            )
                        }
                        .frame(height: 270)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(alignment: .topTrailing) {
                            Button {
                                controller.previewMicroReminder()
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .help("settings.breakAppearance.fullscreenPreview")
                            .padding(14)
                        }

                        Divider()

                        HStack {
                            Text("settings.reminderInterval")
                                .font(.body.weight(.semibold))
                            Spacer()
                            Picker("settings.reminderInterval", selection: reminderInterval) {
                                ForEach(reminderIntervals, id: \.self) { duration in
                                    Text(Self.formattedDuration(duration)).tag(duration)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)

                        Divider()

                        HStack {
                            Text("settings.microReminderDesign.sidekick")
                                .font(.body.weight(.semibold))
                            Spacer()
                            Button {
                                showingMascotPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    MicroReminderMascotView(
                                        mascot: controller.configuration.microReminderMascot,
                                        color: controller.configuration.microReminderColor,
                                        size: 30,
                                        animated: false
                                    )
                                    Text(LocalizedStringKey(controller.configuration.microReminderMascot.titleKey))
                                        .font(.callout.weight(.medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 38)
                                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 60)
                    }
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.13), lineWidth: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .overlay {
            if showingMascotPicker {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.68)
                            .onTapGesture { showingMascotPicker = false }

                        MascotWheelPicker(
                            mascot: controller.configuration.microReminderMascot,
                            color: controller.configuration.microReminderColor,
                            onSelectColor: updateColor,
                            onClose: { showingMascotPicker = false },
                            availableSize: geometry.size
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingMascotPicker)
    }

    private var reminderInterval: Binding<TimeInterval> {
        Binding {
            controller.configuration.microReminderInterval
        } set: { newValue in
            var configuration = controller.configuration
            configuration.microReminderInterval = newValue
            controller.updateConfiguration(configuration)
        }
    }

    private func updateColor(_ color: MicroReminderColor) {
        var configuration = controller.configuration
        configuration.microReminderColor = color
        controller.updateConfiguration(configuration)
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Measurement(value: seconds / 60, unit: UnitDuration.minutes)
            .formatted(.measurement(width: .wide, usage: .asProvided))
    }
}

private struct MicroReminderArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.19, blue: 0.42),
                        Color(red: 0.05, green: 0.10, blue: 0.33)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                beam(geometry, top: 0.18...0.37, bottom: -0.25...0.11,
                     color: Color(red: 0.09, green: 0.39, blue: 0.73))
                beam(geometry, top: 0.32...0.47, bottom: 0.08...0.31,
                     color: Color(red: 0.05, green: 0.27, blue: 0.57))
                beam(geometry, top: 0.42...0.51, bottom: 0.26...0.50,
                     color: Color(red: 0.09, green: 0.47, blue: 0.69).opacity(0.55))
                beam(geometry, top: 0.49...0.58, bottom: 0.45...0.71,
                     color: Color(red: 0.96, green: 0.55, blue: 0.28).opacity(0.70))
                beam(geometry, top: 0.57...0.67, bottom: 0.70...1.03,
                     color: Color(red: 1.00, green: 0.77, blue: 0.46).opacity(0.82))
                beam(geometry, top: 0.65...0.76, bottom: 0.88...1.24,
                     color: Color(red: 0.94, green: 0.43, blue: 0.29).opacity(0.58))

                LinearGradient(
                    colors: [.clear, Color(red: 0.02, green: 0.07, blue: 0.27).opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func beam(
        _ geometry: GeometryProxy,
        top: ClosedRange<CGFloat>,
        bottom: ClosedRange<CGFloat>,
        color: Color
    ) -> some View {
        Path { path in
            let width = geometry.size.width
            let height = geometry.size.height
            path.move(to: CGPoint(x: top.lowerBound * width, y: 0))
            path.addLine(to: CGPoint(x: top.upperBound * width, y: 0))
            path.addLine(to: CGPoint(x: bottom.upperBound * width, y: height))
            path.addLine(to: CGPoint(x: bottom.lowerBound * width, y: height))
            path.closeSubpath()
        }
        .fill(color)
    }
}

private struct MascotWheelPicker: View {
    let mascot: MicroReminderMascot
    let color: MicroReminderColor
    let onSelectColor: (MicroReminderColor) -> Void
    let onClose: () -> Void
    let availableSize: CGSize

    var body: some View {
        let panelWidth = min(availableSize.width - 24, 390)
        let panelHeight = min(availableSize.height - 24, 440)
        let wheelSize = min(panelWidth - 48, panelHeight - 148)

        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.13), in: Circle())
                        .overlay { Circle().stroke(.white.opacity(0.2), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Kapat")
            }

            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    let angle = CGFloat(-120 + index * 60)
                    let isSelected = index == 4

                    MascotWheelSegment(
                        startAngle: angle - 28.5,
                        endAngle: angle + 28.5
                    )
                    .fill(isSelected ? Color.blue.opacity(0.20) : .white.opacity(0.07))
                    .overlay {
                        MascotWheelSegment(
                            startAngle: angle - 28.5,
                            endAngle: angle + 28.5
                        )
                        .stroke(isSelected ? Color(red: 0.39, green: 0.62, blue: 1) : .white.opacity(0.16),
                                lineWidth: isSelected ? 2 : 1)
                    }

                    if isSelected {
                        MicroReminderMascotView(
                            mascot: .flame,
                            color: color,
                            size: wheelSize * 0.17,
                            animated: false
                        )
                        .position(
                            x: wheelSize * 0.5 + wheelSize * 0.33 * CGFloat(cos(Double(angle) * .pi / 180)),
                            y: wheelSize * 0.5 + wheelSize * 0.33 * CGFloat(sin(Double(angle) * .pi / 180))
                        )
                    }
                }

                Circle()
                    .fill(Color(red: 0.17, green: 0.19, blue: 0.28).opacity(0.94))
                    .frame(width: wheelSize * 0.36, height: wheelSize * 0.36)
                    .overlay {
                        Circle().stroke(.white.opacity(0.18), lineWidth: 1.5)
                    }

                VStack(spacing: 3) {
                    MicroReminderMascotView(
                        mascot: mascot,
                        color: color,
                        size: wheelSize * 0.18,
                        animated: false
                    )
                    Text(LocalizedStringKey(mascot.titleKey))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(width: wheelSize * 0.32)
                .allowsHitTesting(false)
            }
            .frame(width: wheelSize, height: wheelSize)

            HStack(spacing: 7) {
                ForEach(MicroReminderColor.allCases) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onSelectColor(option)
                        }
                    } label: {
                        Circle()
                            .fill(LinearGradient(
                                colors: option.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 22, height: 22)
                            .overlay { Circle().stroke(.white.opacity(0.3), lineWidth: 1) }
                            .padding(3)
                            .overlay {
                                Circle()
                                    .stroke(color == option ? Color(red: 0.39, green: 0.62, blue: 1) : .clear,
                                            lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(option.titleKey)))
                    .help(Text(LocalizedStringKey(option.titleKey)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08), in: Capsule())
        }
        .padding(16)
        .frame(width: panelWidth, height: panelHeight)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.20, blue: 0.20),
                    Color(red: 0.16, green: 0.18, blue: 0.27),
                    Color(red: 0.13, green: 0.14, blue: 0.19)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.55), radius: 26, y: 14)
        .onExitCommand(perform: onClose)
    }
}

private struct MascotWheelSegment: Shape {
    let startAngle: CGFloat
    let endAngle: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.49
        let innerRadius = radius * 0.40
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        for step in 0...24 {
            let degrees = startAngle + (endAngle - startAngle) * CGFloat(step) / 24
            let radians = Double(degrees) * .pi / 180
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(radians)),
                y: center.y + radius * CGFloat(sin(radians))
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for step in (0...24).reversed() {
            let degrees = startAngle + (endAngle - startAngle) * CGFloat(step) / 24
            let radians = Double(degrees) * .pi / 180
            path.addLine(to: CGPoint(
                x: center.x + innerRadius * CGFloat(cos(radians)),
                y: center.y + innerRadius * CGFloat(sin(radians))
            ))
        }
        path.closeSubpath()
        return path
    }
}

private struct FocusDesignView: View {
    let controller: SessionController
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: onBack) {
                    Label("settings.sidebar.focus", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Text("settings.focusDesign.title")
                    .font(.title2.weight(.semibold))

                BreakMiniPreviewCard(
                    configuration: controller.configuration,
                    onFullscreen: { controller.previewBreak() }
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.breakAppearance.sectionTitle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                                // None / Calm gradient
                                WallpaperChoiceThumbnail(
                                    background: .calmGradient,
                                    title: "settings.breakAppearance.none",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.calmGradient)
                                    }
                                ) {
                                    ZStack {
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.08, green: 0.10, blue: 0.14),
                                                Color(red: 0.04, green: 0.05, blue: 0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )

                                        Image(systemName: "circle.slash")
                                            .font(.system(size: 22, weight: .light))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }

                                // Mountain Lake (Lake Tahoe)
                                WallpaperChoiceThumbnail(
                                    background: .mountainLake,
                                    title: "settings.breakAppearance.mountainLake",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.mountainLake)
                                    }
                                ) {
                                    Image("BreakMountainLake")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Snow Peaks
                                WallpaperChoiceThumbnail(
                                    background: .snowPeaks,
                                    title: "settings.breakAppearance.snowPeaks",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.snowPeaks)
                                    }
                                ) {
                                    Image("BreakSnowPeaks")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Aurora
                                WallpaperChoiceThumbnail(
                                    background: .aurora,
                                    title: "settings.breakAppearance.aurora",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.aurora)
                                    }
                                ) {
                                    Image("BreakAurora")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Desert Dunes
                                WallpaperChoiceThumbnail(
                                    background: .desertDunes,
                                    title: "settings.breakAppearance.desertDunes",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.desertDunes)
                                    }
                                ) {
                                    Image("BreakDesertDunes")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Cosmic Space
                                WallpaperChoiceThumbnail(
                                    background: .cosmic,
                                    title: "settings.breakAppearance.cosmic",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.cosmic)
                                    }
                                ) {
                                    Image("BreakCosmic")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Custom Wallpaper upload button / choice
                                CustomWallpaperChoiceThumbnail(
                                    customPath: controller.configuration.customWallpaperPath,
                                    isSelected: controller.configuration.breakBackground == .custom,
                                    onSelect: {
                                        if controller.configuration.customWallpaperPath != nil {
                                            updateBackground(.custom)
                                        } else {
                                            chooseCustomWallpaper()
                                        }
                                    },
                                    onPickNew: {
                                        chooseCustomWallpaper()
                                    }
                                )
                        }
                        .padding(16)
                    }
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.breakSound.title")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("settings.breakSound.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        Toggle(isOn: soundEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("settings.breakSound.enabled")
                                    .font(.body.weight(.medium))
                                Text("settings.breakSound.enabledDescription")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)

                        Divider()

                        HStack {
                            Text("settings.breakSound.choice")
                                .foregroundStyle(controller.configuration.breakSoundEnabled ? .primary : .secondary)
                            Spacer()
                            Picker("settings.breakSound.choice", selection: soundChoice) {
                                ForEach(BreakSound.allCases) { sound in
                                    Text(sound.rawValue).tag(sound)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            .disabled(!controller.configuration.breakSoundEnabled)
                        }
                        .padding(16)
                    }
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.breakLayout.title")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("settings.breakLayout.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        ForEach(BreakLayout.allCases) { layout in
                            Button {
                                var configuration = controller.configuration
                                configuration.breakLayout = layout
                                controller.updateConfiguration(configuration)
                            } label: {
                                VStack(spacing: 8) {
                                    BreakLayoutThumbnail(layout: layout)
                                    Text(layout == .horizon ? "settings.breakLayout.horizon" : "settings.breakLayout.gentleBar")
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(
                                    controller.configuration.breakLayout == layout
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.black.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(controller.configuration.breakLayout == layout ? Color.accentColor : .gray.opacity(0.25), lineWidth: 1.5)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(controller.configuration.breakLayout == .horizon
                         ? "settings.breakLayout.horizonDescription"
                         : "settings.breakLayout.gentleBarDescription")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private var soundEnabled: Binding<Bool> {
        Binding {
            controller.configuration.breakSoundEnabled
        } set: { value in
            var configuration = controller.configuration
            configuration.breakSoundEnabled = value
            controller.updateConfiguration(configuration)
        }
    }

    private var soundChoice: Binding<BreakSound> {
        Binding {
            controller.configuration.breakSound
        } set: { value in
            var configuration = controller.configuration
            configuration.breakSound = value
            controller.updateConfiguration(configuration)
        }
    }

    private func updateBackground(_ background: BreakBackground) {
        var configuration = controller.configuration
        configuration.breakBackground = background
        controller.updateConfiguration(configuration)
    }

    private func chooseCustomWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Seç"
        panel.message = "Mola ekranı için bir arka plan görseli seçin"

        if panel.runModal() == .OK, let url = panel.url {
            saveCustomWallpaper(from: url)
        }
    }

    private func saveCustomWallpaper(from sourceURL: URL) {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }

        let kaskasFolder = appSupport.appendingPathComponent("com.ramazanozbek.kaskas", isDirectory: true)
        try? FileManager.default.createDirectory(at: kaskasFolder, withIntermediateDirectories: true)

        let targetURL = kaskasFolder.appendingPathComponent("custom_wallpaper.\(sourceURL.pathExtension)")
        try? FileManager.default.removeItem(at: targetURL)
        try? FileManager.default.copyItem(at: sourceURL, to: targetURL)

        var config = controller.configuration
        config.customWallpaperPath = targetURL.path
        config.breakBackground = .custom
        controller.updateConfiguration(config)
    }
}

private struct BreakMiniPreviewCard: View {
    let configuration: FocusConfiguration
    let onFullscreen: () -> Void

    var body: some View {
        ZStack {
            // Live rendering of the background
            BreakBackgroundView(
                background: configuration.breakBackground,
                customWallpaperPath: configuration.customWallpaperPath
            )

            // Scaled miniature break content
            VStack(spacing: 5) {
                // Top localized date
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 14)

                Spacer()

                if configuration.breakLayout == .gentleBar {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("break.title")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .lineLimit(2)
                            Text("break.message")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .lineLimit(2)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                        VStack(alignment: .trailing, spacing: 7) {
                            Text("00:20")
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            HStack(spacing: 4) {
                                miniPill(title: "break.snooze", icon: "clock")
                                miniPill(title: "break.skip", icon: "forward.fill")
                                miniPill(title: "break.lockScreen", icon: "lock.fill")
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.bottom, 16)
                } else {
                    VStack(spacing: 4) {
                        Text("break.title")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 1)

                        Text("break.message")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)

                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(width: 36, height: 1.5)
                            .padding(.top, 2)

                        Text("00:20")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 5, y: 2)

                        HStack(spacing: 8) {
                            miniPill(title: "break.snooze", icon: "clock.arrow.circlepath")
                            miniPill(title: "break.skip", icon: "forward.end.fill")
                            miniPill(title: "break.lockScreen", icon: "lock.fill")
                        }
                        .padding(.top, 2)

                        HStack(spacing: 3) {
                            Text("break.press")
                            Text("esc")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 2.5))
                            Text("break.toSkip")
                        }
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .tracking(0.8)
                    }
                }

                if configuration.breakLayout == .horizon {
                    Spacer()
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)

            // Top overlay bar with Live Preview badge and Fullscreen button
            VStack {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)

                        Text("settings.breakAppearance.livePreview")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5)
                    }

                    Spacer()

                    Button(action: onFullscreen) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay {
                                Circle().stroke(.white.opacity(0.2), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .help("settings.breakAppearance.fullscreenPreview")
                }
                .padding(12)

                Spacer()
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
    }

    private func miniPill(title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(title)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5)
        }
    }
}

private struct BreakLayoutThumbnail: View {
    let layout: BreakLayout

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.black.opacity(0.48))

            if layout == .horizon {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.35))
                        .frame(width: 52, height: 15)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.22))
                        .frame(width: 35, height: 4)
                }
            } else {
                HStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.35))
                        .frame(width: 30, height: 6)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.35))
                        .frame(width: 34, height: 15)
                }
                .padding(12)
            }
        }
        .frame(height: 78)
    }
}

private struct WallpaperChoiceThumbnail<Content: View>: View {
    let background: BreakBackground
    let title: LocalizedStringKey
    let selectedBackground: BreakBackground
    let onSelect: () -> Void
    @ViewBuilder let content: Content

    private var isSelected: Bool {
        selectedBackground == background
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                content
                    .frame(width: 96, height: 60)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.accentColor : .white.opacity(0.15),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(5)
                        }
                    }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CustomWallpaperChoiceThumbnail: View {
    let customPath: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onPickNew: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    if let path = customPath, let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.black.opacity(0.3)

                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 96, height: 60)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if customPath == nil {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, dash: [4])
                            )
                            .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.25))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.accentColor : .white.opacity(0.15),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(5)
                    }
                }
                .contextMenu {
                    Button("settings.breakAppearance.upload", action: onPickNew)
                }

                Text(customPath == nil ? "settings.breakAppearance.upload" : "settings.breakAppearance.custom")
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WellnessSettingsView: View {
    let controller: SessionController

    private let reminderIntervals: [TimeInterval] = [5, 10, 15, 20, 25, 30].map { $0 * 60 }

    var body: some View {
        Form {
            Section("settings.wellness.section") {
                SettingsDurationRow(
                    title: "settings.reminderInterval",
                    subtitle: "settings.reminderInterval.description",
                    selection: reminderInterval,
                    options: reminderIntervals
                )
            }
        }
        .formStyle(.grouped)
    }

    private var reminderInterval: Binding<TimeInterval> {
        Binding {
            controller.configuration.microReminderInterval
        } set: { newValue in
            var configuration = controller.configuration
            configuration.microReminderInterval = newValue
            controller.updateConfiguration(configuration)
        }
    }
}

private struct SettingsDurationRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var selection: TimeInterval
    let options: [TimeInterval]

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { duration in
                    Text(Self.formattedDuration(duration))
                        .tag(duration)
                }
            }
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Measurement(
            value: seconds / 60,
            unit: UnitDuration.minutes
        ).formatted(
            .measurement(width: .wide, usage: .asProvided)
        )
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

private struct GeneralSettingsView: View {
    let controller: SessionController

    var body: some View {
        Form {
            Section("settings.privacy.title") {
                LabeledContent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } label: {
                    Label("settings.privacy.local", systemImage: "lock.shield")
                }
            }
#if DEBUG
            DebugSettingsView(controller: controller)
#endif
        }
        .formStyle(.grouped)
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
        if !context.coordinator.isConfigured, let window = nsView.window {
            configure(window: window)
            context.coordinator.isConfigured = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var isConfigured = false
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

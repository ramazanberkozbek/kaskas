import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FocusDesignView: View {
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

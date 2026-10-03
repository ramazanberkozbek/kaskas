import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FocusDesignView: View {
    let controller: SessionController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("settings.focusDesign.title")
                    .font(.title2.weight(.semibold))

                BreakMiniPreviewCard(
                    configuration: controller.configuration,
                    onFullscreen: { controller.previewBreak() }
                )

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.breakAppearance.sectionTitle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("settings.breakAppearance.sectionSubtitle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                                // Ocean
                                WallpaperChoiceThumbnail(
                                    background: .ocean,
                                    title: "settings.breakAppearance.ocean",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.ocean)
                                    }
                                ) {
                                    Image("BreakOcean")
                                        .resizable()
                                        .scaledToFill()
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

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.breakLayout.title")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("settings.breakLayout.subtitle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

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
        .scrollIndicators(.hidden)
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
        panel.prompt = String(localized: "Seç")
        panel.message = String(localized: "settings.breakAppearance.chooseImageMessage", defaultValue: "Mola ekranı için bir arka plan görseli seçin")

        if panel.runModal() == .OK, let url = panel.url {
            saveCustomWallpaper(from: url)
        }
    }

    private func saveCustomWallpaper(from sourceURL: URL) {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }

        let folderName = Bundle.main.bundleIdentifier ?? "Kaskas"
        let kaskasFolder = appSupport.appendingPathComponent(folderName, isDirectory: true)
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



struct BreakLayoutThumbnail: View {
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

struct WallpaperChoiceThumbnail<Content: View>: View {
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

struct CustomWallpaperChoiceThumbnail: View {
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

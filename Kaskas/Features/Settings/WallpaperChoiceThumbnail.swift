import AppKit
import SwiftUI

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

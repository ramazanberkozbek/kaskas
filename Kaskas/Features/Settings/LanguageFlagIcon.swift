import AppKit
import SwiftUI

@MainActor private var flagImageCache: [String: Image] = [:]

@MainActor
func languageFlagImage(for code: String) -> Image {
    if let cached = flagImageCache[code] {
        return cached
    }
    let renderer = ImageRenderer(content: LanguageFlagIcon(code: code))
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
    if let image = renderer.nsImage {
        let img = Image(nsImage: image)
        flagImageCache[code] = img
        return img
    }
    let fallback = Image(systemName: code == "system" ? "globe" : "flag.fill")
    flagImageCache[code] = fallback
    return fallback
}

struct LanguageFlagIcon: View {
    let code: String

    private let width: CGFloat = 20
    private let height: CGFloat = 14

    var body: some View {
        ZStack {
            flagBackground
            flagOverlay
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
        )
        .frame(width: width, height: height, alignment: .center)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var flagBackground: some View {
        switch code {
        case "system":
            Color.white
        case "en":
            Color.white
        case "tr":
            Color(red: 0.89, green: 0.09, blue: 0.18)
        default:
            Color.gray.opacity(0.2)
        }
    }

    @ViewBuilder
    private var flagOverlay: some View {
        switch code {
        case "system":
            Image(systemName: "globe")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        case "en":
            unionJackOverlay()
        case "tr":
            crescentAndDot()
        default:
            EmptyView()
        }
    }

    private func unionJackOverlay() -> some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .frame(width: width * 0.18)
            Rectangle()
                .fill(Color.red)
                .frame(height: height * 0.18)
        }
    }

    private func crescentAndDot() -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 6.5, height: 6.5)
                .offset(x: -2)
            Circle()
                .fill(Color(red: 0.89, green: 0.09, blue: 0.18))
                .frame(width: 5.2, height: 5.2)
                .offset(x: -0.8)
            Circle()
                .fill(Color.white)
                .frame(width: 1.6, height: 1.6)
                .offset(x: 3.4, y: -0.2)
        }
    }
}

import AppKit
import SwiftUI

/// Align the visible arrow, excluding the native cursor image's transparent padding.
struct SettingsCursorArrow: View {
    // NSCursor's canvas includes asymmetric transparent padding. Crop it so
    // layout aligns the visible arrow with the center of the pause badge.
    private static let pointerImage: NSImage = {
        let image = NSCursor.arrow.image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = -1, maxY = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.1 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let cropped = cgImage.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
        else { return image }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }()

    var body: some View {
        Image(nsImage: Self.pointerImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 16, height: 26)
            .accessibilityHidden(true)
    }
}

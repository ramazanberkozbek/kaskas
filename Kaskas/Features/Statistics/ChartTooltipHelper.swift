import SwiftUI

struct ChartHoverGuide: View {
    let x: CGFloat
    let plot: CGRect

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
        }
        .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .allowsHitTesting(false)
    }
}

enum ChartTooltipPosition {
    static func originX(for x: CGFloat, in plot: CGRect, width: CGFloat = 230, spacing: CGFloat = 14) -> CGFloat {
        let preferred = x + spacing + width <= plot.maxX ? x + spacing : x - spacing - width
        return min(max(plot.minX, preferred), max(plot.minX, plot.maxX - width))
    }
}

struct ChartTooltipRow: View {
    let label: Text
    let value: String
    let color: Color

    init(_ key: LocalizedStringKey, value: String, color: Color) {
        self.label = Text(key)
        self.value = value
        self.color = color
    }

    init(_ text: String, value: String, color: Color, isLocalizedKey: Bool = true) {
        self.label = isLocalizedKey ? Text(LocalizedStringKey(text)) : Text(verbatim: text)
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            label
            Spacer(minLength: 8)
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }
}

extension View {
    func chartTooltip(width: CGFloat = 230) -> some View {
        self
            .font(.subheadline)
            .padding(12)
            .frame(width: width, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.17)))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
    }
}

import SwiftUI

// MARK: - Tamga Model

/// 16-bit canonical Tamga compound glyph (values 0...65,535).
/// Four base-16 regions around a central vertical stem.
nonisolated struct TamgaModel: Equatable, Hashable, Sendable {
    static let minValue: Int = 0
    static let maxValue: Int = 65_535

    static let viewBoxWidth: CGFloat = 104
    static let viewBoxHeight: CGFloat = 138
    static let aspectRatio: CGFloat = 104 / 138
    static let baseStrokeWidth: CGFloat = 2.4

    let value: Int

    init(value: Int) {
        self.value = min(max(value, Self.minValue), Self.maxValue)
    }

    var place0: UInt8 { UInt8(value & 0x0F) }
    var place1: UInt8 { UInt8((value >> 4) & 0x0F) }
    var place2: UInt8 { UInt8((value >> 8) & 0x0F) }
    var place3: UInt8 { UInt8((value >> 12) & 0x0F) }

    func digit(forPlace place: Int) -> UInt8 {
        switch place {
        case 0: place0
        case 1: place1
        case 2: place2
        case 3: place3
        default: 0
        }
    }

    func activeOz(forPlace place: Int) -> [Int] {
        let d = digit(forPlace: place)
        return [8, 4, 2, 1].filter { (d & UInt8($0)) != 0 }
    }
}

// MARK: - Tamga Geometry

nonisolated private enum TamgaGeometry {
    // Binary weights with their top-half y coordinate and horizontal bar length.
    static let bars: [(oz: Int, topY: CGFloat, length: CGFloat)] = [
        (1, -63, 5.5),
        (2, -45, 11.0),
        (4, -27, 22.0),
        (8, -9, 44.0)
    ]

    // (xDirection, isBottomHalf) for places 0...3
    static let quadrants: [(xDir: CGFloat, isBottom: Bool)] = [
        (-1, false), // Place 0: Top-Left
        (1, false),  // Place 1: Top-Right
        (-1, true),  // Place 2: Bottom-Left
        (1, true)    // Place 3: Bottom-Right
    ]

    static func yCoord(topY: CGFloat, isBottom: Bool) -> CGFloat {
        isBottom ? -topY : topY
    }
}

// MARK: - Tamga Shapes

nonisolated struct TamgaBarsShape: Shape {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    init(value: Int) {
        self.value = Double(value)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }

        let scale = min(rect.width / TamgaModel.viewBoxWidth, rect.height / TamgaModel.viewBoxHeight)
        let midX = rect.midX
        let midY = rect.midY

        path.move(to: CGPoint(x: midX, y: midY - 63 * scale))
        path.addLine(to: CGPoint(x: midX, y: midY + 63 * scale))

        let model = TamgaModel(value: Int(value.rounded()))

        for (place, quad) in TamgaGeometry.quadrants.enumerated() {
            let digit = model.digit(forPlace: place)
            for bar in TamgaGeometry.bars where (digit & UInt8(bar.oz)) != 0 {
                let y = midY + TamgaGeometry.yCoord(topY: bar.topY, isBottom: quad.isBottom) * scale
                path.move(to: CGPoint(x: midX, y: y))
                path.addLine(to: CGPoint(x: midX + quad.xDir * bar.length * scale, y: y))
            }
        }
        return path
    }
}

nonisolated struct TamgaSubdivisionsShape: Shape {
    var value: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }

        let scale = min(rect.width / TamgaModel.viewBoxWidth, rect.height / TamgaModel.viewBoxHeight)
        let midX = rect.midX
        let midY = rect.midY
        let tickHalf: CGFloat = 0.9 * scale
        let model = TamgaModel(value: value)

        for (place, quad) in TamgaGeometry.quadrants.enumerated() {
            let digit = model.digit(forPlace: place)
            for bar in TamgaGeometry.bars where bar.oz > 1 && (digit & UInt8(bar.oz)) != 0 {
                let y = midY + TamgaGeometry.yCoord(topY: bar.topY, isBottom: quad.isBottom) * scale
                for i in 1..<bar.oz {
                    let fraction = CGFloat(i) / CGFloat(bar.oz)
                    let x = midX + quad.xDir * bar.length * fraction * scale
                    path.move(to: CGPoint(x: x, y: y - tickHalf))
                    path.addLine(to: CGPoint(x: x, y: y + tickHalf))
                }
            }
        }
        return path
    }
}

nonisolated struct TamgaGuideDotsShape: Shape {
    var value: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }

        let scale = min(rect.width / TamgaModel.viewBoxWidth, rect.height / TamgaModel.viewBoxHeight)
        let midX = rect.midX
        let midY = rect.midY
        let markerRadius = 1.05 * scale
        let markerOffset = 1.8 * scale
        let model = TamgaModel(value: value)

        for (place, quad) in TamgaGeometry.quadrants.enumerated() {
            let digit = model.digit(forPlace: place)
            for bar in TamgaGeometry.bars where (digit & UInt8(bar.oz)) == 0 {
                let y = midY + TamgaGeometry.yCoord(topY: bar.topY, isBottom: quad.isBottom) * scale
                let x = midX + quad.xDir * markerOffset
                path.addEllipse(in: CGRect(
                    x: x - markerRadius,
                    y: y - markerRadius,
                    width: markerRadius * 2,
                    height: markerRadius * 2
                ))
            }
        }
        return path
    }
}

// MARK: - Tamga Glyph View

struct TamgaGlyphView: View {
    let value: Int
    var strokeColor: Color = .white
    var strokeWidth: CGFloat? = nil
    var showSubdivisions: Bool = true
    var showGuides: Bool = true
    var glowRadius: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / TamgaModel.viewBoxWidth,
                geometry.size.height / TamgaModel.viewBoxHeight
            )
            let actualStrokeWidth = strokeWidth ?? max(0.6, TamgaModel.baseStrokeWidth * scale)
            let subStrokeWidth = max(0.4, 0.55 * scale)

            ZStack {
                if showGuides {
                    TamgaGuideDotsShape(value: value)
                        .fill(strokeColor.opacity(0.28))
                }

                TamgaBarsShape(value: value)
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(lineWidth: actualStrokeWidth, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: glowRadius > 0 ? strokeColor.opacity(0.35) : .clear, radius: glowRadius, y: 1)

                if showSubdivisions {
                    TamgaSubdivisionsShape(value: value)
                        .stroke(
                            strokeColor.opacity(0.40),
                            style: StrokeStyle(lineWidth: subStrokeWidth, lineCap: .round)
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(TamgaModel.aspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("settings.breakTimerStyle.tamga"))
    }
}

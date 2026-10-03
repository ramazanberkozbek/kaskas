import SwiftUI

struct MicroReminderArtwork: View {
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

struct MascotWheelPicker: View {
    private let slots: [MicroReminderMascot?] = [.flame, nil, nil, .glasses, nil, nil]

    let mascot: MicroReminderMascot
    let color: MicroReminderColor
    let onSelectMascot: (MicroReminderMascot) -> Void
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
                .accessibilityLabel("Kapat")
            }

            ZStack {
                ForEach(slots.indices, id: \.self) { index in
                    let angle = CGFloat(180 - index * 60)
                    if let option = slots[index] {
                        Button {
                            onSelectMascot(option)
                        } label: {
                            wheelSegment(at: angle, option: option, size: wheelSize)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(LocalizedStringKey(option.titleKey)))
                        .accessibilityAddTraits(option == mascot ? .isSelected : [])
                    } else {
                        wheelSegment(at: angle, option: nil, size: wheelSize)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
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

    private func wheelSegment(at angle: CGFloat, option: MicroReminderMascot?, size: CGFloat) -> some View {
        let shape = MascotWheelSegment(startAngle: angle - 28, endAngle: angle + 28)
        let isSelected = option == mascot

        return shape
            .fill(isSelected ? Color.blue.opacity(0.20) : .white.opacity(0.07))
            .overlay {
                shape.stroke(
                    isSelected ? Color(red: 0.39, green: 0.62, blue: 1) : .white.opacity(0.16),
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .overlay {
                if let option {
                    MicroReminderMascotView(
                        mascot: option,
                        color: color,
                        size: size * 0.19,
                        animated: false
                    )
                    .position(
                        x: size * 0.5 + size * 0.33 * CGFloat(cos(Double(angle) * .pi / 180)),
                        y: size * 0.5 + size * 0.33 * CGFloat(sin(Double(angle) * .pi / 180))
                    )
                    .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
    }
}

nonisolated struct MascotWheelSegment: Shape {
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

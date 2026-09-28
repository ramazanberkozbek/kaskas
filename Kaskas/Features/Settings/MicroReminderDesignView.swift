import SwiftUI

struct MicroReminderDesignView: View {
    let controller: SessionController
    let onBack: () -> Void
    @State private var showingMascotPicker = false

    private let reminderIntervals: [TimeInterval] = [5, 10, 15, 20, 25, 30].map { $0 * 60 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            FocusDesignBackButton(action: onBack)
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
                            onSelectMascot: updateMascot,
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

    private func updateMascot(_ mascot: MicroReminderMascot) {
        var configuration = controller.configuration
        configuration.microReminderMascot = mascot
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
                .help("Kapat")
            }

            ZStack {
                ForEach(MicroReminderMascot.allCases.indices, id: \.self) { index in
                    let option = MicroReminderMascot.allCases[index]
                    let angle = CGFloat(180 - index * 180)
                    let isSelected = option == mascot

                    Button {
                        onSelectMascot(option)
                    } label: {
                        MascotWheelSegment(
                            startAngle: angle - 88,
                            endAngle: angle + 88
                        )
                        .fill(isSelected ? Color.blue.opacity(0.20) : .white.opacity(0.07))
                        .overlay {
                            MascotWheelSegment(
                                startAngle: angle - 88,
                                endAngle: angle + 88
                            )
                            .stroke(isSelected ? Color(red: 0.39, green: 0.62, blue: 1) : .white.opacity(0.16),
                                    lineWidth: isSelected ? 2 : 1)
                        }
                        .overlay {
                            MicroReminderMascotView(
                                mascot: option,
                                color: color,
                                size: wheelSize * 0.19,
                                animated: false
                            )
                            .position(
                                x: wheelSize * 0.5 + wheelSize * 0.33 * CGFloat(cos(Double(angle) * .pi / 180)),
                                y: wheelSize * 0.5 + wheelSize * 0.33 * CGFloat(sin(Double(angle) * .pi / 180))
                            )
                            .allowsHitTesting(false)
                        }
                        .contentShape(MascotWheelSegment(
                            startAngle: angle - 88,
                            endAngle: angle + 88
                        ))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(option.titleKey)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .help(Text(LocalizedStringKey(option.titleKey)))
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

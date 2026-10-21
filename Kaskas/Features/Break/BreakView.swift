import AppKit
import SwiftUI

struct BreakView: View {
    let endsAt: Date
    let configuration: FocusConfiguration
    let isPreview: Bool
    let onSnooze: () -> Void
    let onSkip: () -> Void
    let onLockScreen: () -> Void
    let onOpenSettings: () -> Void

    init(
        endsAt: Date,
        configuration: FocusConfiguration,
        isPreview: Bool = false,
        onSnooze: @escaping () -> Void = {},
        onSkip: @escaping () -> Void = {},
        onLockScreen: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.endsAt = endsAt
        self.configuration = configuration
        self.isPreview = isPreview
        self.onSnooze = onSnooze
        self.onSkip = onSkip
        self.onLockScreen = onLockScreen
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                BreakBackgroundView(
                    background: configuration.breakBackground,
                    customWallpaperPath: configuration.customWallpaperPath
                )

                if configuration.breakLayout == .gentleBar {
                    gentleBarLayout(now: context.date)
                } else {
                    VStack(spacing: 0) {
                        clockHeader(now: context.date)
                            .padding(.top, 40)
                            .breakReveal(delay: 0.45)

                        Spacer()

                        VStack(spacing: 34) {
                            VStack(spacing: 12) {
                                Text("break.title")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.35), radius: 10, y: 3)

                                Text("break.message")
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                            }

                            let totalSeconds = Self.remainingSeconds(until: endsAt, now: context.date)
                            let formattedRemaining = Self.formattedRemaining(
                                until: endsAt,
                                now: context.date
                            )

                            timerDisplay(
                                totalSeconds: totalSeconds,
                                formattedRemaining: formattedRemaining,
                                fontSize: 96,
                                tamgaHeight: 150,
                                shadowRadius: 12,
                                shadowY: 4
                            )
                        }
                        .multilineTextAlignment(.center)
                        .breakReveal(delay: 0.55)

                        Spacer()

                        actionButtons(spacing: 16)
                            .padding(.bottom, 64)
                            .breakReveal(delay: 0.7)
                    }
                    .padding(.horizontal, Theme.Spacing.extraLarge)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    private func gentleBarLayout(now: Date) -> some View {
        VStack(spacing: 0) {
            clockHeader(now: now)
                .padding(.top, 40)
                .breakReveal(delay: 0.45)

            Spacer()

            HStack(alignment: .bottom, spacing: 40) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("break.title")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.65)
                        .lineLimit(2)
                        .foregroundStyle(.white)

                    Text("break.message")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 18) {
                    let totalSeconds = Self.remainingSeconds(until: endsAt, now: now)
                    let remaining = Self.formattedRemaining(until: endsAt, now: now)

                    timerDisplay(
                        totalSeconds: totalSeconds,
                        formattedRemaining: remaining,
                        fontSize: 88,
                        tamgaHeight: 125,
                        shadowRadius: 0,
                        shadowY: 0
                    )

                    actionButtons(spacing: 10)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .shadow(color: .black.opacity(0.45), radius: 9, y: 3)
            .padding(.bottom, 46)
            .breakReveal(delay: 0.55)

            HStack(spacing: 6) {
                Text("break.press")
                Text("esc")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                Text("break.toSkip")
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.bottom, 28)
            .breakReveal(delay: 0.7)
        }
        .padding(.horizontal, 48)
    }

    @ViewBuilder
    private func timerDisplay(
        totalSeconds: Int,
        formattedRemaining: String,
        fontSize: CGFloat,
        tamgaHeight: CGFloat,
        shadowRadius: CGFloat,
        shadowY: CGFloat
    ) -> some View {
        Group {
            switch configuration.breakTimerStyle {
            case .standard:
                Text(formattedRemaining)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.45), value: formattedRemaining)
                    .foregroundStyle(.white)
                    .shadow(color: shadowRadius > 0 ? .black.opacity(0.4) : .clear, radius: shadowRadius, y: shadowY)

            case .tamga:
                TamgaGlyphView(
                    value: totalSeconds,
                    strokeColor: .white,
                    showSubdivisions: true,
                    showGuides: true,
                    glowRadius: 10
                )
                .frame(height: tamgaHeight)
                .animation(.snappy(duration: 0.4), value: totalSeconds)
            }
        }
        .accessibilityLabel("break.remaining.label")
        .accessibilityValue(formattedRemaining)
    }

    private func actionButtons(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            BreakActionButton(title: "break.snooze", icon: "clock", action: onSnooze)
            BreakActionButton(title: "break.skip", icon: "forward.fill", action: onSkip)
            BreakActionButton(title: "break.lockScreen", icon: "lock.fill", action: onLockScreen)
        }
    }

    private func clockHeader(now: Date) -> some View {
        let locale = configuration.appLanguage.locale
        return VStack(spacing: 4) {
            Text(now, format: .dateTime.hour().minute().locale(locale))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text(now, format: .dateTime.weekday(.wide).day().month(.abbreviated).locale(locale))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .tracking(0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }

    private static func remainingSeconds(until endDate: Date, now: Date) -> Int {
        max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }

    private static func formattedRemaining(until endDate: Date, now: Date) -> String {
        let totalSeconds = remainingSeconds(until: endDate, now: now)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

struct BreakActionButton: View {
    let title: LocalizedStringKey
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial)
            .background(
                isHovered
                    ? Color.white.opacity(0.25)
                    : Color.white.opacity(0.12)
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        Color.white.opacity(isHovered ? 0.50 : 0.22),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct BreakBackgroundView: View {
    let background: BreakBackground
    let customWallpaperPath: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                imageLayer
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                Color.black.opacity(0.35)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var imageLayer: some View {
        if background == .custom, let path = customWallpaperPath {
            ZStack {
                fallbackGradient
                PreparedCustomWallpaperImage(path: path)
            }
        } else if let assetName = background.assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            fallbackGradient
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.10, blue: 0.16),
                Color(red: 0.08, green: 0.22, blue: 0.28),
                Color(red: 0.03, green: 0.07, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

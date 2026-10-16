import AppKit
import SwiftUI

/// Drives the reveal and dismissal animation shared by every break panel.
@MainActor
final class BreakRevealState: ObservableObject {
    @Published var isRevealed = false
}

enum BreakTransitionTiming {
    static let dismissDuration: TimeInterval = 0.35
}

/// Blurs the desktop behind the panel, then fades the break background in over it.
struct BreakTransitionContainer<Content: View>: View {
    @ObservedObject var revealState: BreakRevealState
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isRevealed = revealState.isRevealed
        ZStack {
            DesktopBlurView()
                .opacity(isRevealed ? 1 : 0)
                .animation(
                    isRevealed ? .easeOut(duration: 0.5) : .easeIn(duration: BreakTransitionTiming.dismissDuration),
                    value: isRevealed
                )

            content()
                .opacity(isRevealed ? 1 : 0)
                .scaleEffect(isRevealed || reduceMotion ? 1 : 1.06)
                .animation(
                    isRevealed
                        ? .easeOut(duration: 1.1).delay(0.2)
                        : .easeIn(duration: BreakTransitionTiming.dismissDuration),
                    value: isRevealed
                )
        }
        .environment(\.isBreakRevealed, isRevealed)
        .ignoresSafeArea()
    }
}

private struct DesktopBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .fullScreenUI
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct BreakRevealedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isBreakRevealed: Bool {
        get { self[BreakRevealedKey.self] }
        set { self[BreakRevealedKey.self] = newValue }
    }
}

private struct BreakRevealModifier: ViewModifier {
    let delay: TimeInterval

    @Environment(\.isBreakRevealed) private var isRevealed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed || reduceMotion ? 0 : 18)
            .animation(
                isRevealed
                    ? .spring(response: 0.6, dampingFraction: 0.85).delay(delay)
                    : .easeIn(duration: BreakTransitionTiming.dismissDuration * 0.6),
                value: isRevealed
            )
    }
}

extension View {
    /// Staggers a section of the break screen in after the background has appeared.
    func breakReveal(delay: TimeInterval) -> some View {
        modifier(BreakRevealModifier(delay: delay))
    }
}

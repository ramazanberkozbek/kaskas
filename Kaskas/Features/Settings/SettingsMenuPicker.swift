import AppKit
import SwiftUI

/// A native pull-down menu with the same minimum width as its glass control.
struct SettingsMenuPicker<Selection: Hashable, Options: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Selection
    let selectedLabel: Text
    var width: CGFloat = 170
    var customAction: (() -> Void)? = nil
    @ViewBuilder let options: Options

    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                control
                    .glassEffect(.regular.interactive(isEnabled), in: RoundedRectangle(cornerRadius: 6))
            } else {
                control
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .dropdownHoverEffect()
    }

    private var control: some View {
        HStack(spacing: 8) {
            selectedLabel
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: 28)
        .foregroundStyle(isEnabled ? .primary : .tertiary)
        .accessibilityHidden(true)
        .overlay {
            SettingsNativeMenu(width: width, isEnabled: isEnabled) {
                Picker(title, selection: $selection) {
                    options
                }
                .pickerStyle(.inline)
                .labelsHidden()
                if let customAction {
                    Divider()
                    Button("settings.duration.custom", action: customAction)
                }
            }
            .environment(\.locale, locale)
            .environment(\.colorScheme, colorScheme)
            .accessibilityLabel(Text(title))
            .accessibilityValue(selectedLabel)
        }
    }
}

private struct SettingsNativeMenu<Content: View>: NSViewRepresentable {
    let width: CGFloat
    let isEnabled: Bool
    @ViewBuilder let content: Content
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    private var menuContent: AnyView {
        AnyView(content
            .environment(\.locale, locale)
            .environment(\.colorScheme, colorScheme))
    }

    func makeCoordinator() -> SettingsNativeMenuModel {
        SettingsNativeMenuModel()
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        // SwiftUI draws the label; AppKit owns menu sizing, anchoring,
        // keyboard navigation and selection. No selected row covers the label.
        button.usesItemFromMenu = false
        button.isTransparent = true
        context.coordinator.content = menuContent
        // `NSHostingMenu.rootView`'s setter aborts inside AttributeGraph on
        // recent macOS ("saw AnyView, expected Optional<AnyView>"), so the
        // root view is set exactly once and later updates flow through the model.
        button.menu = NSHostingMenu(rootView: SettingsNativeMenuRoot(model: context.coordinator))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.content = menuContent
        button.menu?.minimumWidth = width
        button.isEnabled = isEnabled
    }
}

@MainActor @Observable
private final class SettingsNativeMenuModel {
    var content = AnyView(EmptyView())
}

private struct SettingsNativeMenuRoot: View {
    let model: SettingsNativeMenuModel

    var body: some View {
        model.content
    }
}

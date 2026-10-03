import AppKit
import SwiftUI

struct CategoryRuleRow: View {
    let rule: CategoryRule
    let categories: [AppCategory]
    let locale: Locale
    let onCategoryChange: (String) -> Void
    let onDeleteRule: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App Icon (Fixed 32x32)
            CategoryAppIconView(bundleId: rule.appIdentifier, appName: rule.displayName)
                .frame(width: 32, height: 32)

            // App Name & Bundle ID
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                    .font(.system(size: 13, weight: .semibold))

                Text(rule.appIdentifier)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Category Dropdown Picker
            let currentCategory = categories.first(where: { $0.id == rule.categoryId }) ?? .other
            Menu {
                ForEach(categories) { cat in
                    Button {
                        onCategoryChange(cat.id)
                    } label: {
                        HStack {
                            Image(systemName: cat.iconName)
                            Text(cat.localizedName(for: locale))
                            if cat.id == rule.categoryId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: currentCategory.iconName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(currentCategory.localizedName(for: locale))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Delete Rule Button
            Button(action: onDeleteRule) {
                Image(systemName: "trash")
            }
            .buttonStyle(HeaderActionButtonStyle(isDestructive: true))
            .accessibilityLabel(rule.isDefault ? String(localized: "categories.rules.removeRule") : String(localized: "categories.rules.removeOverride"))
        }
        .padding(.horizontal, SettingsPageLayout.cardInset)
        .padding(.vertical, 9)
    }
}

struct CategoryAppIconView: View {
    let bundleId: String
    let appName: String

    var body: some View {
        Group {
            if let icon = CategoryRegistry.iconForApp(bundleId: bundleId, appName: appName) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    Image(systemName: "app.dashed")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 32)
            }
        }
    }
}

struct HeaderActionButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    @State private var isHovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(
                isDestructive
                    ? (isHovered || configuration.isPressed ? Color.red : Color.secondary)
                    : (configuration.isPressed ? Color.primary : (isHovered ? Color.primary : Color.secondary))
            )
            .frame(width: 28, height: 28)
            .background(
                configuration.isPressed
                    ? (isDestructive ? Color.red.opacity(0.18) : Color.primary.opacity(0.12))
                    : (isHovered ? (isDestructive ? Color.red.opacity(0.10) : Color.primary.opacity(0.07)) : Color.clear),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

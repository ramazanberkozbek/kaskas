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
            CategoryAppIconView(bundleId: rule.appIdentifier, appName: rule.displayName)
                .frame(width: 32, height: 32)

            Text(rule.displayName)
                .font(CategorySettingsTypography.label)
                .lineLimit(1)

            Spacer()

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
                        .font(CategorySettingsTypography.label)
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
            .dropdownHoverEffect()

            Button(action: onDeleteRule) {
                Image(systemName: "trash")
            }
            .buttonStyle(HeaderActionButtonStyle(isDestructive: true))
            .accessibilityLabel(rule.isDefault ? String(localized: "categories.rules.removeRule", locale: locale) : String(localized: "categories.rules.removeOverride", locale: locale))
            .help(Text(rule.isDefault ? LocalizedStringKey("categories.rules.removeRule") : LocalizedStringKey("categories.rules.removeOverride")))
        }
        .padding(.horizontal, SettingsPageLayout.cardInset)
        .padding(.vertical, 9)
    }
}

struct CategoryAppIconView: View {
    let bundleId: String
    let appName: String
    var path: String? = nil
    var size: CGFloat = 32
    @State private var icon: NSImage?
    @State private var loadedRequest: IconLoadID?
    @Environment(\.categoryApplicationRevision) private var installationRevision

    private struct IconLoadID: Equatable {
        let request: CategoryApplicationWorker.IconRequest
        let revision: Int
    }

    private var loadID: IconLoadID {
        IconLoadID(request: request, revision: installationRevision)
    }

    private var request: CategoryApplicationWorker.IconRequest {
        .init(bundleId: bundleId, appName: appName, path: path)
    }

    var body: some View {
        Group {
            if loadedRequest == loadID, let icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
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
                .frame(width: size, height: size)
            }
        }
        .task(id: loadID) {
            let requested = loadID
            let loaded = await CategoryRegistry.loadIcon(for: requested.request)
            guard !Task.isCancelled else { return }
            icon = loaded
            loadedRequest = requested
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

private struct CategoryApplicationRevisionKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var categoryApplicationRevision: Int {
        get { self[CategoryApplicationRevisionKey.self] }
        set { self[CategoryApplicationRevisionKey.self] = newValue }
    }
}

import AppKit
import SwiftUI

struct AddCategoryRuleSheet: View {
    let registry: CategoryRegistry
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appSearchText: String = ""
    @State private var selectedApp: CategoryRegistry.DiscoveredApp? = nil
    @State private var categoryName: String = ""
    @State private var categoryIcon: String = "folder.fill"
    @State private var showingIconPickerPopover: Bool = false
    @State private var iconSearchText: String = ""
    @State private var installedApps: [CategoryRegistry.DiscoveredApp] = []
    @State private var isLoadingApps: Bool = false

    private var filteredInstalledApps: [CategoryRegistry.DiscoveredApp] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.name.lowercased().contains(query) ||
            $0.bundleId.lowercased().contains(query)
        }
    }


    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Yeni Kural Ekle")
                        .font(.headline)
                    Text("Mac'inizdeki bir uygulamayı seçin ve çalışma kategorisini belirleyin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Search installed apps
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yüklü Uygulamayı Seçin")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Yüklü uygulama ara (örn: Cursor, Xcode, Arc)...", text: $appSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        if !appSearchText.isEmpty {
                            Button {
                                appSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                    // App Selection List
                    ScrollView {
                        if isLoadingApps && installedApps.isEmpty {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Yüklü uygulamalar taranıyor...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else if filteredInstalledApps.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3)
                                    .foregroundStyle(.tertiary)
                                Text(appSearchText.isEmpty ? "Hiçbir uygulama bulunamadı" : "Eşleşen uygulama bulunamadı")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredInstalledApps) { app in
                                    Button {
                                        selectedApp = app
                                    } label: {
                                        HStack(spacing: 10) {
                                            appIcon(for: app)
                                                .frame(width: 24, height: 24)

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(app.name)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(.primary)
                                                Text(app.bundleId)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }

                                            Spacer(minLength: 0)

                                            if selectedApp?.bundleId == app.bundleId {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(RoundedRectangle(cornerRadius: 8))
                                        .background(
                                            selectedApp?.bundleId == app.bundleId
                                                ? Color.accentColor.opacity(0.12)
                                                : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(height: 190)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }

                // Target Category — single-line: icon picker + text field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Atanacak Kategori")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        // Icon picker trigger button
                        Button {
                            showingIconPickerPopover.toggle()
                        } label: {
                            Image(systemName: categoryIcon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingIconPickerPopover, arrowEdge: .bottom) {
                            iconPickerPopover
                        }

                        // Category name text field
                        HStack {
                            TextField("Kategori adı yazın (örn: Yazılım, Ders, Borsa)...", text: $categoryName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))

                            if !categoryName.isEmpty {
                                Button {
                                    categoryName = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 24, height: 24)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }

                    // Quick-select: existing categories as suggestion chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(registry.categories) { cat in
                                Button {
                                    categoryName = cat.name
                                    categoryIcon = cat.iconName
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: cat.iconName)
                                            .font(.system(size: 11))
                                        Text(cat.name)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(
                                        categoryName == cat.name ? Color.accentColor : .secondary
                                    )
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(
                                        categoryName == cat.name
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.primary.opacity(0.04),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                categoryName == cat.name
                                                    ? Color.accentColor.opacity(0.3)
                                                    : Color.primary.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                                    .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Footer
            HStack {
                Button("İptal") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Kuralı Kaydet") {
                    saveRule()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedApp == nil || categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 500)
        .task {
            if installedApps.isEmpty {
                isLoadingApps = true
                let apps = await CategoryRegistry.discoverInstalledApplicationsAsync()
                installedApps = apps
                isLoadingApps = false
            }
        }
    }

    private func appIcon(for app: CategoryRegistry.DiscoveredApp) -> some View {
        Group {
            if let icon = CategoryRegistry.iconForApp(bundleId: app.bundleId, appName: app.name, path: app.path) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
    }

    private func saveRule() {
        guard let app = selectedApp else { return }
        let cleanName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanId = app.bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCategoryName.isEmpty else { return }

        // Check if this matches an existing category by name
        var targetCategoryId: String
        if let existingCategory = registry.categories.first(where: { $0.name.caseInsensitiveCompare(cleanCategoryName) == .orderedSame }) {
            targetCategoryId = existingCategory.id
            // If the user changed the icon, update the category's icon too
            if categoryIcon != existingCategory.iconName {
                registry.addOrUpdateCategory(
                    name: existingCategory.name,
                    iconName: categoryIcon,
                    colorName: existingCategory.colorName,
                    id: existingCategory.id
                )
            }
        } else {
            // Create a new category with the typed name and chosen icon
            let newCategory = registry.addOrUpdateCategory(
                name: cleanCategoryName,
                iconName: categoryIcon,
                colorName: "blue"
            )
            targetCategoryId = newCategory.id
        }

        registry.addOrUpdateRule(
            appIdentifier: cleanId.isEmpty ? cleanName : cleanId,
            displayName: cleanName,
            categoryId: targetCategoryId
        )
        onSave()
        dismiss()
    }

    private var filteredIcons: [String] {
        let query = iconSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return AppCategory.suggestedIcons }
        return AppCategory.suggestedIcons.filter { $0.lowercased().contains(query) }
    }

    private var iconPickerPopover: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("İkon ara...", text: $iconSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !iconSearchText.isEmpty {
                    Button {
                        iconSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

            // Grid of icons
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 6), spacing: 6) {
                    ForEach(filteredIcons, id: \.self) { icon in
                        Button {
                            categoryIcon = icon
                            showingIconPickerPopover = false
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 15))
                                .frame(width: 34, height: 34)
                                .foregroundStyle(categoryIcon == icon ? Color.accentColor : .primary)
                                .background(
                                    categoryIcon == icon
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.primary.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            categoryIcon == icon ? Color.accentColor.opacity(0.4) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
            .frame(height: 190)
        }
        .padding(10)
        .frame(width: 270, height: 250)
    }
}

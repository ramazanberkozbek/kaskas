import AppKit
import SwiftUI

struct AddCategoryRuleSheet: View {
    let registry: CategoryRegistry
    let initialCategory: AppCategory?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appSearchText: String = ""
    @State private var selectedAppIDs: Set<String> = []
    @State private var savedAppCount: Int = 0
    private enum CategorySelection: Hashable {
        case none
        case existing(String)
        case new
    }

    @State private var categorySelection: CategorySelection
    @FocusState private var isCategoryNameFocused: Bool
    @State private var categoryName: String
    @State private var categoryIcon: String
    @State private var showingIconPickerPopover: Bool = false
    @State private var installedApps: [CategoryRegistry.DiscoveredApp] = []
    @State private var isLoadingApps: Bool = false
    @State private var appCategories: [String: AppCategory] = [:]

    init(registry: CategoryRegistry, initialCategory: AppCategory? = nil, onSave: @escaping () -> Void) {
        self.registry = registry
        self.initialCategory = initialCategory
        self.onSave = onSave
        _categorySelection = State(initialValue: initialCategory.map { .existing($0.id) } ?? .none)
        _categoryName = State(initialValue: "")
        _categoryIcon = State(initialValue: initialCategory?.iconName ?? "folder.fill")
    }

    private var filteredInstalledApps: [CategoryRegistry.DiscoveredApp] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.name.lowercased().contains(query) ||
            $0.bundleId.lowercased().contains(query)
        }
    }

    // Resolve once after discovery or a registry change, never while rendering rows.
    private func refreshAppCategories() {
        let rules = registry.allRules
        let categories = Dictionary(uniqueKeysWithValues: registry.categories.map { ($0.id, $0) })
        let defaults = Dictionary(uniqueKeysWithValues: AppCategory.defaultCategories.map { ($0.id, $0) })
        let resolver = registry.resolverSnapshot()
        var assignments: [String: AppCategory] = [:]
        for app in installedApps {
            if let rule = rules.first(where: { $0.matches(bundleId: app.bundleId, appName: app.name) }) {
                assignments[app.id] = categories[rule.categoryId] ?? defaults[rule.categoryId]
            } else {
                let resolution = resolver.resolve(bundleID: app.bundleId, appName: app.name)
                if resolution.isResolved {
                    assignments[app.id] = categories[resolution.categoryID] ?? defaults[resolution.categoryID]
                }
            }
        }
        appCategories = assignments
    }

    private var selectedCategory: AppCategory? {
        guard case .existing(let id) = categorySelection else { return nil }
        return registry.category(for: id)
    }

    private var hasValidCategory: Bool {
        switch categorySelection {
        case .none: return false
        case .existing: return selectedCategory != nil
        case .new: return !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var selectedApps: [CategoryRegistry.DiscoveredApp] {
        installedApps.filter { selectedAppIDs.contains($0.id) }
    }

    var body: some View {
        let visibleApps = filteredInstalledApps
        VStack(spacing: 0) {
            HStack {
                Text("categories.apps.add")
                    .font(.headline)
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
                .help(Text("categories.actions.close"))
                .accessibilityLabel(Text("categories.actions.close"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Uygulama ara", text: $appSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
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
                        .opacity(appSearchText.isEmpty ? 0 : 1)
                        .disabled(appSearchText.isEmpty)
                        .accessibilityHidden(appSearchText.isEmpty)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

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
                        } else if visibleApps.isEmpty {
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
                            LazyVStack(spacing: 0) {
                                ForEach(visibleApps) { app in
                                    let currentCategory = appCategories[app.id]
                                    let isSelected = selectedAppIDs.contains(app.id)

                                    CategoryApplicationSelectionRow(
                                        app: app,
                                        category: currentCategory,
                                        isSelected: isSelected,
                                        showsDivider: app.id != visibleApps.last?.id
                                    ) {
                                        savedAppCount = 0
                                        if isSelected {
                                            selectedAppIDs.remove(app.id)
                                        } else {
                                            selectedAppIDs.insert(app.id)
                                            if categorySelection == .none, let currentCategory,
                                               registry.category(for: currentCategory.id) != nil {
                                                categorySelection = .existing(currentCategory.id)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: 280)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Kategori")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Menu {
                        Picker("Kategori", selection: $categorySelection) {
                            if categorySelection == .none {
                                Text("categories.rules.chooseCategory")
                                    .tag(CategorySelection.none)
                            }
                            ForEach(registry.categories) { category in
                                Label {
                                    Text(category.localizedName)
                                } icon: {
                                    Image(systemName: category.iconName)
                                        .foregroundStyle(category.color)
                                }
                                .tag(CategorySelection.existing(category.id))
                            }
                            Divider()
                            Label("categories.rules.newCategory", systemImage: "plus")
                                .tag(CategorySelection.new)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } label: {
                        HStack(spacing: 8) {
                            if let category = selectedCategory {
                                Image(systemName: category.iconName)
                                    .foregroundStyle(category.color)
                                Text(category.localizedName)
                                    .lineLimit(1)
                            } else if categorySelection == .new {
                                Label("categories.rules.newCategory", systemImage: "plus")
                            } else {
                                Text("categories.rules.chooseCategory")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .dropdownHoverEffect()
                    .accessibilityLabel(Text("Kategori"))

                    if categorySelection == .new {
                        HStack(spacing: 8) {
                            Button {
                                showingIconPickerPopover.toggle()
                            } label: {
                                Image(systemName: categoryIcon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.blue)
                                    .frame(width: 28, height: 28)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("categories.rules.chooseIcon"))
                            .help(Text("categories.rules.chooseIcon"))
                            .popover(isPresented: $showingIconPickerPopover, arrowEdge: .bottom) {
                                CategoryIconPickerPopover(selectedIcon: $categoryIcon) {
                                    showingIconPickerPopover = false
                                }
                            }

                            HStack {
                                TextField("Kategori adı", text: $categoryName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .focused($isCategoryNameFocused)

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
                                .opacity(categoryName.isEmpty ? 0 : 1)
                                .disabled(categoryName.isEmpty)
                                .accessibilityHidden(categoryName.isEmpty)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }

                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            HStack {
                Button("İptal") {
                    dismiss()
                }
                .font(CategorySettingsTypography.label)
                .keyboardShortcut(.cancelAction)

                if savedAppCount > 0 {
                    Text("\(savedAppCount) uygulama kaydedildi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !selectedAppIDs.isEmpty {
                    Text("\(selectedAppIDs.count) uygulama seçildi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("categories.actions.assign") {
                    saveRule()
                }
                .font(CategorySettingsTypography.label)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedAppIDs.isEmpty || !hasValidCategory)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 500)
        .task {
            if installedApps.isEmpty {
                isLoadingApps = true
                let apps = await CategoryRegistry.discoverInstalledApplicationsAsync()
                guard !Task.isCancelled else { return }
                installedApps = apps
                refreshAppCategories()
                isLoadingApps = false
            }
        }
        .onChange(of: categorySelection) { _, selection in
            showingIconPickerPopover = false
            isCategoryNameFocused = selection == .new
        }
        .onChange(of: registry.revision) { _, _ in
            refreshAppCategories()
        }
    }

    private func saveRule() {
        let apps = selectedApps
        guard !apps.isEmpty else { return }
        guard hasValidCategory else { return }

        let targetCategoryId: String
        switch categorySelection {
        case .none:
            return
        case .existing(let id):
            targetCategoryId = id
        case .new:
            let cleanName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = registry.categories.first(where: {
                $0.localizedName.caseInsensitiveCompare(cleanName) == .orderedSame ||
                $0.name.caseInsensitiveCompare(cleanName) == .orderedSame
            }) {
                targetCategoryId = existing.id
            } else {
                targetCategoryId = registry.addOrUpdateCategory(
                    name: cleanName,
                    iconName: categoryIcon,
                    colorName: "blue"
                ).id
            }
            categorySelection = .existing(targetCategoryId)
            categoryName = ""
            categoryIcon = "folder.fill"
        }

        for app in apps {
            let cleanName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanId = app.bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
            registry.addOrUpdateRule(
                appIdentifier: cleanId.isEmpty ? cleanName : cleanId,
                displayName: cleanName,
                categoryId: targetCategoryId
            )
        }
        selectedAppIDs.removeAll()
        savedAppCount = apps.count
        onSave()
    }
}

// Local hover state avoids rebuilding the sheet and the other application rows.
// A single root per ForEach element also lets LazyVStack defer offscreen rows.
private struct CategoryApplicationSelectionRow: View {
    let app: CategoryRegistry.DiscoveredApp
    let category: AppCategory?
    let isSelected: Bool
    let showsDivider: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    CategoryAppIconView(bundleId: app.bundleId, appName: app.name, path: app.path, size: 24)
                        .frame(width: 24, height: 24)

                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let category {
                        Image(systemName: category.iconName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(category.color)
                            .help(category.localizedName)
                            .accessibilityLabel(category.localizedName)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.18))
                }
                .padding(.horizontal, 10)
                .frame(height: 46)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .background(
                    isSelected ? Color.accentColor.opacity(0.12)
                        : (isHovered ? Color.primary.opacity(0.06) : Color.clear),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)

            if showsDivider {
                Divider()
                    .padding(.leading, 44)
                    .padding(.trailing, 10)
            }
        }
    }
}

import AppKit
import SwiftUI

struct CategorySettingsView: View {
    let controller: SessionController
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var showingAddSheet: Bool = false
    @State private var categoryForNewRule: AppCategory? = nil
    @State private var showingAddCategorySheet: Bool = false
    @State private var showingResetAlert: Bool = false
    @State private var isResetHovered: Bool = false
    @State private var categoryToDelete: AppCategory? = nil
    @State private var expandedCategories: Set<String> = []
    @State private var hasInitializedExpansion: Bool = false

    // Inline category editing
    @State private var editingCategoryId: String? = nil
    @State private var editingCategoryName: String = ""
    @State private var editingCategoryIcon: String = ""
    @State private var editIconSearchText: String = ""
    @State private var showingEditIconPopover: Bool = false
    @FocusState private var isNameFieldFocused: Bool

    private var registry: CategoryRegistry {
        controller.categoryRegistry
    }

    private var availableRules: [CategoryRule] {
        registry.installedRules
    }

    private var groupedFilteredRules: [String: [CategoryRule]] {
        let baseRules = availableRules
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered: [CategoryRule]
        if query.isEmpty {
            filtered = baseRules
        } else {
            filtered = baseRules.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.appIdentifier.lowercased().contains(query)
            }
        }

        return Dictionary(grouping: filtered, by: \.categoryId)
    }

    private func filteredRules(for categoryId: String) -> [CategoryRule] {
        groupedFilteredRules[categoryId] ?? []
    }

    private var totalMatchingCount: Int {
        groupedFilteredRules.values.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                SettingsPaneHeader(title: "settings.sidebar.categories")

                // Search and category actions
                HStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        TextField("Uygulama ara", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: 320)
                    .background(
                        colorScheme == .dark
                            ? Color(red: 0.12, green: 0.12, blue: 0.12)
                            : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            showingAddCategorySheet = true
                        } label: {
                            Label("Kategori Ekle", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button {
                            categoryForNewRule = nil
                            showingAddSheet = true
                        } label: {
                            Label("Kural Ekle", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }

                // Sub-header Bar: Count & Expand/Collapse All
                HStack(alignment: .center) {
                    Text("\(totalMatchingCount) uygulama")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        toggleAllCategories()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: areAllExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                            Text(areAllExpanded ? "Tümünü Daralt" : "Tümünü Genişlet")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Folder-like Expandable Category Sections
                VStack(spacing: 12) {
                    ForEach(registry.categories) { category in
                        let categoryRules = filteredRules(for: category.id)
                        categoryFolderCard(category: category, rules: categoryRules)
                    }
                }

                // Bottom Footer: Reset to defaults
                HStack {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .medium))
                            Text("Varsayılana Sıfırla")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(isResetHovered ? Color.red.opacity(0.1) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isResetHovered ? Color.red : .secondary)
                    .onHover { isResetHovered = $0 }

                    Spacer()
                }
                .padding(.top, 4)
            }
            .settingsPageContent()
        }
        .scrollIndicators(.hidden)
        .background(colorScheme == .dark ? Color(red: 0.075, green: 0.075, blue: 0.075) : Color(nsColor: .windowBackgroundColor))
        .task { _ = await CategoryRegistry.discoverInstalledApplicationsAsync() }
        .sheet(isPresented: $showingAddSheet) {
            AddCategoryRuleSheet(registry: registry, initialCategory: categoryForNewRule) {
                if let cat = categoryForNewRule {
                    expandedCategories.insert(cat.id)
                    saveExpansionState()
                }
            }
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            AddCategorySheet(registry: registry) { newCategory in
                expandedCategories.insert(newCategory.id)
                saveExpansionState()
            }
        }
        .confirmationDialog(
            "\"\(categoryToDelete?.localizedName ?? "")\" kategorisini silmek istiyor musunuz?",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Kategoriyi Sil", role: .destructive) {
                if let cat = categoryToDelete {
                    registry.removeCategory(id: cat.id)
                    expandedCategories.remove(cat.id)
                    saveExpansionState()
                    categoryToDelete = nil
                }
            }
            Button("Vazgeç", role: .cancel) {
                categoryToDelete = nil
            }
        } message: {
            Text("Bu kategoriye ait tüm uygulamalar 'Diğer' kategorisine aktarılacaktır.")
        }
        .confirmationDialog(
            "Varsayılanlara dönmek istediğinize emin misiniz?",
            isPresented: $showingResetAlert,
            titleVisibility: .visible
        ) {
            Button("Tüm Özel Kuralları Sıfırla", role: .destructive) {
                registry.resetToDefaults()
                expandedCategories.removeAll()
                saveExpansionState()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Eklediğiniz tüm özel uygulama kuralları kaldırılacak ve sistem varsayılanlarına dönülecektir.")
        }
        .onAppear {
            initializeExpansionState()
        }
    }

    // MARK: - Folder-like Category Card

    private func categoryFolderCard(category: AppCategory, rules: [CategoryRule]) -> some View {
        let isExpanded = isCategoryExpanded(category.id)

        return VStack(spacing: 0) {
            // Category Header (Folder style)
            Group {
                if editingCategoryId == category.id {
                    // Inline editing mode
                    HStack(spacing: 8) {
                        Button {
                            toggleCategory(category.id)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(isExpanded ? .degrees(90) : .zero)
                                .animation(.easeInOut(duration: 0.18), value: isExpanded)
                                .frame(width: 20, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Icon picker trigger button
                        Button {
                            showingEditIconPopover.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: editingCategoryIcon)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingEditIconPopover, arrowEdge: .bottom) {
                            editIconPickerPopover(for: category)
                        }
                        .accessibilityLabel("İkonu değiştir")

                        // Category name text field
                        TextField("Kategori adı", text: $editingCategoryName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .focused($isNameFieldFocused)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.08)
                                    : Color.black.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .frame(maxWidth: 240)
                            .onSubmit {
                                saveCategoryEdit(for: category)
                            }
                            .onExitCommand {
                                cancelCategoryEdit()
                            }

                        Text("\(rules.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)


                        Spacer()

                        // Save button
                        Button {
                            saveCategoryEdit(for: category)
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.green, in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Kaydet")
                        .disabled(editingCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        // Cancel button
                        Button {
                            cancelCategoryEdit()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(0.08), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Vazgeç")
                    }
                    .padding(.horizontal, SettingsPageLayout.cardInset)
                    .padding(.vertical, 10)
                } else {
                    HStack(spacing: 0) {
                        // Main full-width clickable button to toggle folder
                        Button {
                            toggleCategory(category.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(isExpanded ? .degrees(90) : .zero)
                                    .animation(.easeInOut(duration: 0.18), value: isExpanded)
                                    .frame(width: 14)

                                Image(systemName: category.iconName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .frame(width: 18)

                                Text(category.localizedName(for: controller.locale))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text("\(rules.count)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)


                                Spacer(minLength: 0)
                            }
                            .padding(.leading, SettingsPageLayout.cardInset)
                            .padding(.trailing, 8)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Action buttons (delete, edit, add)
                        HStack(spacing: 4) {
                            // Allow deleting any category except "Other" (fallback)
                            if category.id != "other" {
                                Button {
                                    categoryToDelete = category
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(HeaderActionButtonStyle(isDestructive: true))
                                .accessibilityLabel("Bu kategoriyi sil")
                            }

                            // Edit Category button (Pencil)
                            Button {
                                startEditing(category)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(HeaderActionButtonStyle())
                            .accessibilityLabel("Bu kategoriyi düzenle")

                            // Add app to this category button (Plus)
                            Button {
                                categoryForNewRule = category
                                showingAddSheet = true
                                expandedCategories.insert(category.id)
                                saveExpansionState()
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(HeaderActionButtonStyle())
                            .accessibilityLabel("Bu kategoriye uygulama ekle")
                        }
                        .padding(.trailing, 10)
                        .padding(.vertical, 8)
                    }
                }
            }

            // Content when folder is expanded
            if isExpanded {
                Divider()
                    .padding(.horizontal, SettingsPageLayout.cardInset)

                if rules.isEmpty {
                    HStack {
                        Text("Bu kategoride tanımlı uygulama bulunmuyor.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            categoryForNewRule = category
                            showingAddSheet = true
                        } label: {
                            Label("Kural Ekle", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, SettingsPageLayout.cardInset)
                    .padding(.vertical, 10)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                            ruleRow(rule: rule)

                            if index < rules.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
            }
        }
        .background(
            colorScheme == .dark
                ? Color(red: 0.115, green: 0.115, blue: 0.115)
                : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func ruleRow(rule: CategoryRule) -> some View {
        HStack(spacing: 12) {
            // App Icon (Fixed 32x32)
            appIconView(for: rule)
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
            let currentCategory = registry.category(for: rule.categoryId) ?? .other
            Menu {
                ForEach(registry.categories) { cat in
                    Button {
                        registry.addOrUpdateRule(
                            appIdentifier: rule.appIdentifier,
                            displayName: rule.displayName,
                            categoryId: cat.id
                        )
                    } label: {
                        HStack {
                            Image(systemName: cat.iconName)
                            Text(cat.localizedName(for: controller.locale))
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
                    Text(currentCategory.localizedName(for: controller.locale))
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

            // Delete Rule Button (all rules are deletable)
            Button {
                registry.removeRule(id: rule.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(HeaderActionButtonStyle(isDestructive: true))
            .accessibilityLabel(rule.isDefault ? String(localized: "categories.rules.removeRule") : String(localized: "categories.rules.removeOverride"))
        }
        .padding(.horizontal, SettingsPageLayout.cardInset)
        .padding(.vertical, 9)
    }

    private func appIconView(for rule: CategoryRule) -> some View {
        Group {
            if let icon = CategoryRegistry.iconForApp(bundleId: rule.appIdentifier, appName: rule.displayName) {
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

    // MARK: - Expansion State Helpers

    private static let expandedCategoriesStorageKey = "kaskas_expanded_category_ids"

    private func isCategoryExpanded(_ categoryId: String) -> Bool {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true // Auto-expand when searching
        }
        return expandedCategories.contains(categoryId)
    }

    private func toggleCategory(_ categoryId: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedCategories.contains(categoryId) {
                expandedCategories.remove(categoryId)
            } else {
                expandedCategories.insert(categoryId)
            }
            saveExpansionState()
        }
    }

    private var areAllExpanded: Bool {
        expandedCategories.count >= registry.categories.count
    }

    private func toggleAllCategories() {
        withAnimation(.easeInOut(duration: 0.18)) {
            if areAllExpanded {
                expandedCategories.removeAll()
            } else {
                expandedCategories = Set(registry.categories.map(\.id))
            }
            saveExpansionState()
        }
    }

    private func initializeExpansionState() {
        guard !hasInitializedExpansion else { return }
        if let saved = UserDefaults.standard.stringArray(forKey: Self.expandedCategoriesStorageKey) {
            expandedCategories = Set(saved)
        } else {
            // Default: All categories collapsed
            expandedCategories = []
        }
        hasInitializedExpansion = true
    }

    private func saveExpansionState() {
        UserDefaults.standard.set(Array(expandedCategories), forKey: Self.expandedCategoriesStorageKey)
    }

    // MARK: - Inline Category Editing

    private func startEditing(_ category: AppCategory) {
        editingCategoryId = category.id
        editingCategoryName = category.localizedName
        editingCategoryIcon = category.iconName
        editIconSearchText = ""
        showingEditIconPopover = false
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func cancelCategoryEdit() {
        editingCategoryId = nil
        editingCategoryName = ""
        editingCategoryIcon = ""
        showingEditIconPopover = false
        isNameFieldFocused = false
    }

    private func saveCategoryEdit(for category: AppCategory) {
        let cleanName = editingCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        registry.addOrUpdateCategory(
            name: cleanName == category.localizedName ? category.name : cleanName,
            iconName: editingCategoryIcon.isEmpty ? category.iconName : editingCategoryIcon,
            colorName: category.colorName,
            id: category.id
        )

        editingCategoryId = nil
        editingCategoryName = ""
        editingCategoryIcon = ""
        showingEditIconPopover = false
        isNameFieldFocused = false
    }

    private var filteredEditIcons: [String] {
        let query = editIconSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return AppCategory.suggestedIcons }
        return AppCategory.suggestedIcons.filter { $0.lowercased().contains(query) }
    }

    private func editIconPickerPopover(for category: AppCategory) -> some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("İkon ara", text: $editIconSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !editIconSearchText.isEmpty {
                    Button {
                        editIconSearchText = ""
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
                    ForEach(filteredEditIcons, id: \.self) { icon in
                        Button {
                            editingCategoryIcon = icon
                            showingEditIconPopover = false
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 15))
                                .frame(width: 34, height: 34)
                                .foregroundStyle(editingCategoryIcon == icon ? Color.accentColor : .primary)
                                .background(
                                    editingCategoryIcon == icon
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.primary.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            editingCategoryIcon == icon ? Color.accentColor.opacity(0.4) : Color.clear,
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
            .scrollIndicators(.hidden)
            .frame(height: 190)
        }
        .padding(10)
        .frame(width: 270, height: 250)
    }
}

// MARK: - Header Action Button Style (macOS Standard Hover & Press Feedback)

private struct HeaderActionButtonStyle: ButtonStyle {
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

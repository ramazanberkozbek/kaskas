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
    @State private var expandedCategories: Set<String>

    private static let expandedCategoriesStorageKey = "kaskas_expanded_category_ids"

    init(controller: SessionController) {
        self.controller = controller
        let saved = UserDefaults.standard.stringArray(forKey: Self.expandedCategoriesStorageKey) ?? []
        _expandedCategories = State(initialValue: Set(saved))
    }

    private var registry: CategoryRegistry {
        controller.categoryRegistry
    }

    @State private var groupedFilteredRules: [String: [CategoryRule]] = [:]
    @State private var totalMatchingCount = 0

    private func rebuildGrouping() {
        let snapshot = CategoryRuleGrouping(rules: registry.installedRules, searchText: searchText)
        groupedFilteredRules = snapshot.groups
        totalMatchingCount = snapshot.count
    }

    private func filteredRules(for categoryId: String) -> [CategoryRule] {
        groupedFilteredRules[categoryId] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                SettingsPaneHeader(title: "settings.sidebar.categories")

                // Search and category actions
                HStack(spacing: 12) {
                    searchBar
                    Spacer()
                    actionButtons
                }

                // Sub-header Bar: Count & Expand/Collapse All
                HStack(alignment: .center) {
                    Text(String(format: String(localized: "%lld uygulama"), totalMatchingCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    toggleAllButton
                }

                // Folder-like Expandable Category Sections
                VStack(spacing: 12) {
                    ForEach(registry.categories) { category in
                        CategoryFolderCard(
                            category: category,
                            rules: filteredRules(for: category.id),
                            allCategories: registry.categories,
                            isExpanded: isCategoryExpanded(category.id),
                            locale: controller.locale,
                            onToggleExpand: { toggleCategory(category.id) },
                            onStartAddRule: {
                                categoryForNewRule = category
                                showingAddSheet = true
                                expandedCategories.insert(category.id)
                                saveExpansionState()
                            },
                            onDeleteCategory: { categoryToDelete = category },
                            onUpdateCategory: { newName, newIcon in
                                registry.addOrUpdateCategory(
                                    name: newName == category.localizedName ? category.name : newName,
                                    iconName: newIcon,
                                    colorName: category.colorName,
                                    id: category.id
                                )
                            },
                            onUpdateRuleCategory: { rule, newCatId in
                                registry.addOrUpdateRule(
                                    appIdentifier: rule.appIdentifier,
                                    displayName: rule.displayName,
                                    categoryId: newCatId
                                )
                            },
                            onDeleteRule: { rule in
                                registry.removeRule(id: rule.id)
                            }
                        )
                    }
                }

                // Bottom Footer: Reset to defaults
                resetToDefaultsFooter
                    .padding(.top, 4)
            }
            .settingsPageContent()
        }
        .environment(\.categoryApplicationRevision, registry.installationRevision)
        .scrollIndicators(.hidden)
        .background(colorScheme == .dark ? Color(red: 0.075, green: 0.075, blue: 0.075) : Color(nsColor: .windowBackgroundColor))
        .task { await registry.refreshInstalledApplications(forceRefresh: true) }
        .onChange(of: registry.installedRules, initial: true) { rebuildGrouping() }
        .onChange(of: searchText) { rebuildGrouping() }
        .sheet(isPresented: $showingAddSheet) {
            AddCategoryRuleSheet(registry: registry, initialCategory: categoryForNewRule) {
                if let cat = categoryForNewRule {
                    expandedCategories.insert(cat.id)
                    saveExpansionState()
                }
            }
            .environment(\.locale, controller.locale)
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            AddCategorySheet(registry: registry) { newCategory in
                expandedCategories.insert(newCategory.id)
                saveExpansionState()
            }
            .environment(\.locale, controller.locale)
        }
        .environment(\.locale, controller.locale)
        .confirmationDialog(
            Text(String(format: String(localized: "\"%@\" kategorisini silmek istiyor musunuz?"), categoryToDelete?.localizedName ?? "")),
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
    }

    // MARK: - Subviews

    private var searchBar: some View {
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
    }

    private var actionButtons: some View {
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

    private var toggleAllButton: some View {
        Button(action: toggleAllCategories) {
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

    private var resetToDefaultsFooter: some View {
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
    }

    // MARK: - Expansion State Helpers

    private func isCategoryExpanded(_ categoryId: String) -> Bool {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
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

    private func saveExpansionState() {
        UserDefaults.standard.set(Array(expandedCategories), forKey: Self.expandedCategoriesStorageKey)
    }
}

/// Built on input changes, never once per category during rendering.
struct CategoryRuleGrouping {
    let groups: [String: [CategoryRule]]
    let count: Int

    init(rules: [CategoryRule], searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = query.isEmpty ? rules : rules.filter {
            $0.displayName.lowercased().contains(query) || $0.appIdentifier.lowercased().contains(query)
        }
        groups = Dictionary(grouping: filtered, by: \.categoryId)
        count = filtered.count
    }
}

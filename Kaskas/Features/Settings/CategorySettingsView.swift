import AppKit
import SwiftUI

struct CategorySettingsView: View {
    let controller: SessionController
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var showingAddSheet: Bool = false
    @State private var showingResetAlert: Bool = false
    @State private var showOnlyInstalled: Bool = true
    @State private var expandedCategories: Set<String> = []
    @State private var hasInitializedExpansion: Bool = false

    private var registry: CategoryRegistry {
        controller.categoryRegistry
    }

    private var availableRules: [CategoryRule] {
        showOnlyInstalled ? registry.installedRules : registry.allRules
    }

    private func filteredRules(for categoryId: String) -> [CategoryRule] {
        var rules = availableRules.filter { $0.categoryId == categoryId }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            rules = rules.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.appIdentifier.lowercased().contains(query)
            }
        }

        return rules
    }

    private var totalMatchingCount: Int {
        registry.categories.reduce(0) { $0 + filteredRules(for: $1.id).count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top Action Toolbar (No large title header)
                HStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        TextField("Uygulama veya Bundle ID ara...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
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

                    // Installed Only Toggle
                    Toggle(isOn: $showOnlyInstalled) {
                        Text("Yalnızca Bu Mac'te Olanlar")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.checkbox)

                    Spacer()

                    // Add Rule Button
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Kural Ekle", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                // Folder-like Expandable Category Sections
                VStack(spacing: 12) {
                    ForEach(registry.categories) { category in
                        let categoryRules = filteredRules(for: category.id)
                        categoryFolderCard(category: category, rules: categoryRules)
                    }
                }

                // Bottom Footer: Reset & Expand/Collapse All
                HStack {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Varsayılan Kurallara Sıfırla", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Toggle expand / collapse all button
                    Button {
                        toggleAllCategories()
                    } label: {
                        Text(areAllExpanded ? "Tümünü Daralt" : "Tümünü Genişlet")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Text("· \(totalMatchingCount) uygulama")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .background(colorScheme == .dark ? Color(red: 0.075, green: 0.075, blue: 0.075) : Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAddSheet) {
            AddCategoryRuleSheet(registry: registry) {
                // Sheet dismissed and saved
            }
        }
        .confirmationDialog(
            "Varsayılanlara dönmek istediğinize emin misiniz?",
            isPresented: $showingResetAlert,
            titleVisibility: .visible
        ) {
            Button("Tüm Özel Kuralları Sıfırla", role: .destructive) {
                registry.resetToDefaults()
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
            // Clickable Category Header (Folder style)
            Button {
                toggleCategory(category.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                        .animation(.easeInOut(duration: 0.18), value: isExpanded)
                        .frame(width: 14)

                    Image(systemName: category.iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    Text(category.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(rules.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content when folder is expanded
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                if rules.isEmpty {
                    HStack {
                        Text("Bu kategoride tanımlı uygulama bulunmuyor.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button("+ Uygulama Ekle") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
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
                HStack(spacing: 7) {
                    Text(rule.displayName)
                        .font(.system(size: 13, weight: .semibold))

                    if !rule.isDefault {
                        Text("Özel")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }

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
                            Text(cat.name)
                            if cat.id == rule.categoryId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: currentCategory.iconName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(currentCategory.name)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Delete Custom Rule Button
            if !rule.isDefault {
                Button {
                    registry.removeRule(id: rule.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Özel kuralı kaldır")
            }
        }
        .padding(.horizontal, 14)
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
        }
    }

    private func initializeExpansionState() {
        guard !hasInitializedExpansion else { return }
        // Expand categories that contain applications by default
        let activeCategories = registry.categories.filter { cat in
            availableRules.contains { $0.categoryId == cat.id }
        }.map(\.id)
        expandedCategories = Set(activeCategories)
        hasInitializedExpansion = true
    }
}

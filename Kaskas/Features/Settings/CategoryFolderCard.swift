import AppKit
import SwiftUI

struct CategoryFolderCard: View {
    let category: AppCategory
    let rules: [CategoryRule]
    let allCategories: [AppCategory]
    let isExpanded: Bool
    let locale: Locale
    let onToggleExpand: () -> Void
    let onStartAddRule: () -> Void
    let onDeleteCategory: () -> Void
    let onUpdateCategory: (String, String) -> Void // (name, icon)
    let onUpdateRuleCategory: (CategoryRule, String) -> Void
    let onDeleteRule: (CategoryRule) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var isEditing: Bool = false
    @State private var editingName: String = ""
    @State private var editingIcon: String = ""
    @State private var showingIconPopover: Bool = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isEditing {
                    editingHeader
                } else {
                    normalHeader
                }
            }

            if isExpanded {
                Divider()
                    .padding(.horizontal, SettingsPageLayout.cardInset)

                if rules.isEmpty {
                    emptyStateRow
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                            CategoryRuleRow(
                                rule: rule,
                                categories: allCategories,
                                locale: locale,
                                onCategoryChange: { newCatId in
                                    onUpdateRuleCategory(rule, newCatId)
                                },
                                onDeleteRule: {
                                    onDeleteRule(rule)
                                }
                            )

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

    // MARK: - Normal Header View

    private var normalHeader: some View {
        HStack(spacing: 0) {
            Button(action: onToggleExpand) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                        .animation(.easeInOut(duration: 0.18), value: isExpanded)
                        .frame(width: 14)

                    Image(systemName: category.iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(category.color)
                        .frame(width: 18)

                    Text(category.localizedName(for: locale))
                        .font(CategorySettingsTypography.label)
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

            HStack(spacing: 4) {
                Button(action: startEditing) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(HeaderActionButtonStyle())
                .accessibilityLabel(Text("categories.actions.edit"))
                .help(Text("categories.actions.edit"))

                if category.id != "other" {
                    Button(action: onDeleteCategory) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(HeaderActionButtonStyle(isDestructive: true))
                    .accessibilityLabel(Text("categories.actions.deleteCategory"))
                    .help(Text("categories.actions.deleteCategory"))
                }
            }
            .padding(.trailing, SettingsPageLayout.cardInset)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Inline Editing Header View

    private var editingHeader: some View {
        HStack(spacing: 8) {
            Button(action: onToggleExpand) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(isExpanded ? .degrees(90) : .zero)
                    .animation(.easeInOut(duration: 0.18), value: isExpanded)
                    .frame(width: 20, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                showingIconPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: editingIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(category.color)
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
            .popover(isPresented: $showingIconPopover, arrowEdge: .bottom) {
                CategoryIconPickerPopover(selectedIcon: $editingIcon) {
                    showingIconPopover = false
                }
            }
            .accessibilityLabel(Text("categories.rules.chooseIcon"))
            .help(Text("categories.rules.chooseIcon"))

            TextField("Kategori adı", text: $editingName)
                .textFieldStyle(.plain)
                .font(CategorySettingsTypography.label)
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
                .onSubmit(saveEditing)
                .onExitCommand(perform: cancelEditing)

            Text("\(rules.count)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: saveEditing) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.green, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Kaydet")
            .help(Text("Kaydet"))
            .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(action: cancelEditing) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.08), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("İptal")
            .help(Text("İptal"))
        }
        .padding(.horizontal, SettingsPageLayout.cardInset)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State

    private var emptyStateRow: some View {
        HStack {
            Text("Bu kategoride tanımlı uygulama bulunmuyor.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
            Button(action: onStartAddRule) {
                Label("categories.apps.add", systemImage: "plus")
                    .font(CategorySettingsTypography.label)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.horizontal, SettingsPageLayout.cardInset)
        .padding(.vertical, 10)
    }

    // MARK: - Editing Helpers

    private func startEditing() {
        editingName = category.localizedName(for: locale)
        editingIcon = category.iconName
        isEditing = true
        showingIconPopover = false
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func cancelEditing() {
        isEditing = false
        editingName = ""
        editingIcon = ""
        showingIconPopover = false
        isNameFieldFocused = false
    }

    private func saveEditing() {
        let cleanName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        onUpdateCategory(cleanName, editingIcon.isEmpty ? category.iconName : editingIcon)
        isEditing = false
        isNameFieldFocused = false
    }
}

import SwiftUI

struct AddCategorySheet: View {
    let registry: CategoryRegistry
    let onSave: (AppCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var categoryName: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var showingIconPickerPopover: Bool = false
    @State private var iconSearchText: String = ""
    @FocusState private var isNameFieldFocused: Bool

    private var isValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Yeni Kategori Ekle")
                        .font(.headline)
                    Text("Özel bir çalışma kategorisi oluşturun.")
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

            // Content: single-line icon picker + text field (matches AddCategoryRuleSheet)
            VStack(alignment: .leading, spacing: 8) {
                Text("Kategori")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    // Icon picker trigger button
                    Button {
                        showingIconPickerPopover.toggle()
                    } label: {
                        Image(systemName: selectedIcon)
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
                        TextField("Kategori adı", text: $categoryName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .focused($isNameFieldFocused)

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

                Button("Kategoriyi Kaydet") {
                    saveCategory()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 360)
        .onAppear {
            isNameFieldFocused = true
        }
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
                TextField("İkon ara", text: $iconSearchText)
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
                            selectedIcon = icon
                            showingIconPickerPopover = false
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 15))
                                .frame(width: 34, height: 34)
                                .foregroundStyle(selectedIcon == icon ? Color.accentColor : .primary)
                                .background(
                                    selectedIcon == icon
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.primary.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            selectedIcon == icon ? Color.accentColor.opacity(0.4) : Color.clear,
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

    private func saveCategory() {
        let cleanName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let category = registry.addOrUpdateCategory(
            name: cleanName,
            iconName: selectedIcon,
            colorName: "blue"
        )
        onSave(category)
        dismiss()
    }
}

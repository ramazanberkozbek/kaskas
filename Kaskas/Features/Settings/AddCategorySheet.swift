import SwiftUI

struct AddCategorySheet: View {
    let registry: CategoryRegistry
    let onSave: (AppCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var categoryName: String = ""
    @State private var selectedIcon: String = "folder.fill"

    private var isValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let iconGridColumns = [
        GridItem(.adaptive(minimum: 36, maximum: 44), spacing: 8)
    ]

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
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                // Live Preview
                VStack(alignment: .leading, spacing: 6) {
                    Text("Önizleme")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Kategori Adı" : categoryName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
                }

                // Category Name Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kategori Adı")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Örn: Ders, Borsa, 3D Modelleme...", text: $categoryName)
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
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }


                // Icon Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("İkon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: iconGridColumns, spacing: 8) {
                        ForEach(AppCategory.suggestedIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 15))
                                    .frame(width: 36, height: 34)
                                    .foregroundStyle(selectedIcon == icon ? Color.accentColor : .secondary)
                                    .background(
                                        selectedIcon == icon
                                            ? Color.accentColor.opacity(0.15)
                                            : Color.primary.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 7)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .strokeBorder(
                                                selectedIcon == icon
                                                    ? Color.accentColor.opacity(0.4)
                                                    : Color.primary.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)

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
            .padding(16)
        }
        .frame(width: 460)
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

import AppKit
import SwiftUI

struct AddCategoryRuleSheet: View {
    let registry: CategoryRegistry
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appSearchText: String = ""
    @State private var selectedApp: CategoryRegistry.DiscoveredApp? = nil
    @State private var manualAppName: String = ""
    @State private var manualAppIdentifier: String = ""
    @State private var selectedCategoryId: String = "coding"
    @State private var installedApps: [CategoryRegistry.DiscoveredApp] = []

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
                }
                .buttonStyle(.plain)
            }
            .padding(18)

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
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                    // App Selection List
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredInstalledApps) { app in
                                Button {
                                    selectedApp = app
                                    manualAppName = app.name
                                    manualAppIdentifier = app.bundleId
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

                                        Spacer()

                                        if selectedApp?.bundleId == app.bundleId {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
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
                    .frame(height: 170)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }

                // Selected / Manual Fields
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Uygulama Adı")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Uygulama Adı", text: $manualAppName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bundle ID")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Bundle ID", text: $manualAppIdentifier)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Target Category
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Atanacak Kategori")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Atanacak Kategori", selection: $selectedCategoryId) {
                            ForEach(registry.categories) { cat in
                                HStack {
                                    Image(systemName: cat.iconName)
                                    Text(cat.name)
                                }
                                .tag(cat.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
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

                Button("Kuralı Kaydet") {
                    saveRule()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(manualAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 500, height: 510)
        .onAppear {
            installedApps = CategoryRegistry.discoverInstalledApplications()
        }
    }

    private func appIcon(for app: CategoryRegistry.DiscoveredApp) -> some View {
        Group {
            if let icon = CategoryRegistry.iconForApp(bundleId: app.bundleId, appName: app.name) {
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
        let cleanName = manualAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanId = manualAppIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.isEmpty {
            cleanId = cleanName
        }

        registry.addOrUpdateRule(
            appIdentifier: cleanId,
            displayName: cleanName,
            categoryId: selectedCategoryId
        )
        onSave()
        dismiss()
    }
}

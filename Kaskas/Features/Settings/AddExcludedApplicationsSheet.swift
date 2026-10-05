import SwiftUI

struct AddExcludedApplicationsSheet: View {
    let preferences: AppExclusionPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var applications: [CategoryRegistry.DiscoveredApp] = []
    @State private var selected: Set<String> = []
    @State private var search = ""
    @State private var isLoading = true

    private var available: [CategoryRegistry.DiscoveredApp] {
        let excluded = preferences.snapshot()
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return applications.filter {
            !$0.bundleId.isEmpty && !excluded.contains(bundleID: $0.bundleId) &&
                (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.bundleId.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("exclusions.add").font(.headline)
            TextField("Uygulama ara", text: $search)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if available.isEmpty {
                    Text("exclusions.noMatches")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(available) { app in
                            Toggle(isOn: Binding(
                                get: { selected.contains(app.bundleId) },
                                set: { included in
                                    if included { selected.insert(app.bundleId) }
                                    else { selected.remove(app.bundleId) }
                                })) {
                                HStack(spacing: 10) {
                                    CategoryAppIconView(bundleId: app.bundleId, appName: app.name, path: app.path, size: 24)
                                        .frame(width: 24, height: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name).font(.system(size: 13, weight: .medium))
                                        Text(app.bundleId).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                            .padding(8)
                        }
                    }
                }
            }
            .frame(height: 270)
            Divider()
            HStack {
                Button("İptal") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("exclusions.confirm") {
                    preferences.add(applications.filter { selected.contains($0.bundleId) }
                        .map { ExcludedApplication(bundleID: $0.bundleId, name: $0.name) })
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
        .task {
            let discovered = await CategoryRegistry.discoverInstalledApplicationsAsync()
            guard !Task.isCancelled else { return }
            var seen: Set<String> = []
            applications = discovered.filter { seen.insert(CategoryResolver.normalize($0.bundleId)).inserted }
            isLoading = false
        }
    }
}

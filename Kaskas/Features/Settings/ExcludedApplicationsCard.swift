import AppKit
import SwiftUI

/// Category-like presentation backed by an independent tracking preference.
struct ExcludedApplicationsCard: View {
    let preferences: AppExclusionPreferences
    let searchText: String
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onAdd: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @State private var showingExplanation = false

    private var applications: [ExcludedApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return preferences.applications.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onToggleExpand) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 14)
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(width: 18)
                        Text("exclusions.title")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("\(applications.count)")
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
                .accessibilityValue(isExpanded ? Text("exclusions.expanded") : Text("exclusions.collapsed"))
                HStack(spacing: 4) {
                    Button { showingExplanation = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(HeaderActionButtonStyle())
                    .accessibilityLabel(Text("exclusions.about"))
                    .popover(isPresented: $showingExplanation) {
                        Text(verbatim: AppLanguage.localizedString("exclusions.historyExplanation", locale: locale))
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(width: 300)
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(HeaderActionButtonStyle())
                    .accessibilityLabel(Text("exclusions.add"))
                    .help(Text("exclusions.add"))
                }
                .padding(.trailing, SettingsPageLayout.cardInset)
                .padding(.vertical, 8)
            }

            if isExpanded {
                Divider().padding(.horizontal, SettingsPageLayout.cardInset)
                if applications.isEmpty {
                    HStack {
                        Text("Bu kategoride tanımlı uygulama bulunmuyor.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button(action: onAdd) {
                            Label("exclusions.add", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, SettingsPageLayout.cardInset)
                    .padding(.vertical, 10)
                } else {
                    ForEach(applications) { app in
                        HStack(spacing: 12) {
                            CategoryAppIconView(bundleId: app.bundleID, appName: app.name)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).font(.system(size: 13, weight: .semibold))
                                Text(app.bundleID)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("exclusions.include") { preferences.remove(bundleID: app.bundleID) }
                                .controlSize(.small)
                        }
                        .padding(.horizontal, SettingsPageLayout.cardInset)
                        .padding(.vertical, 9)
                    }
                }
            }
        }
        .background(colorScheme == .dark ? Color(red: 0.115, green: 0.115, blue: 0.115) : Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }
}

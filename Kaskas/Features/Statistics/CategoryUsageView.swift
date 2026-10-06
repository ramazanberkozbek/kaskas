import SwiftUI

struct CategoryUsageView: View {
    let summary: CategoryUsageSummary
    let registry: CategoryRegistry
    let storageFailed: Bool
    var title: LocalizedStringKey? = "categories.usage.title"
    var subtitle: LocalizedStringKey? = "categories.usage.subtitle"
    var showsAppSegments = true
    var minimumVisibleShare: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private var smallEntries: [CategoryUsageSummary.Entry] {
        guard summary.total > 0 else { return [] }
        return summary.entries.filter { $0.duration > 0 && $0.duration / summary.total < minimumVisibleShare }
    }

    private var smallUndetectedDuration: TimeInterval {
        guard summary.total > 0, summary.undetected / summary.total < minimumVisibleShare else { return 0 }
        return summary.undetected
    }

    private var smallCategoriesDuration: TimeInterval {
        smallEntries.reduce(smallUndetectedDuration) { $0 + $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                if summary.total == 0 {
                    Text("categories.usage.empty")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.entries.filter { $0.duration / summary.total >= minimumVisibleShare }) { entry in
                        let category = registry.historicalCategory(for: entry.categoryID)
                        row(name: category?.localizedName(for: locale) ?? localizedString("categories.usage.deleted", locale: locale),
                            symbol: category?.iconName ?? "tag", color: category?.color ?? .secondary,
                            duration: entry.duration, apps: showsAppSegments ? entry.apps : [])
                    }
                    if summary.undetected > 0 && summary.undetected / summary.total >= minimumVisibleShare {
                        row(name: localizedString("categories.usage.undetected", locale: locale), symbol: "questionmark.circle",
                            color: .secondary, duration: summary.undetected,
                            apps: showsAppSegments ? summary.undetectedApps : [],
                            unrecordedDuration: showsAppSegments ? summary.unrecordedDuration : 0)
                    }
                    if smallCategoriesDuration > 0 {
                        row(name: localizedString("categories.usage.smallCategories", locale: locale),
                            symbol: "square.stack", color: .secondary, duration: smallCategoriesDuration,
                            showsSmallGroups: showsAppSegments)
                    }
                }
                if storageFailed {
                    Label {
                        Text("categories.usage.storageWarning")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                }
            }
            .padding(SettingsPageLayout.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
        }
    }

    private var smallCategoriesBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(smallEntries) { entry in
                    let color = registry.historicalCategory(for: entry.categoryID)?.color ?? .secondary
                    segmentedBar(apps: entry.apps, color: color,
                        unrecordedDuration: entry.apps.isEmpty ? entry.duration : 0,
                        total: entry.duration)
                        .frame(width: geometry.size.width * entry.duration / summary.total)
                        .overlay {
                            Rectangle()
                                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                                .frame(height: 12)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                }
                if smallUndetectedDuration > 0 {
                    segmentedBar(apps: summary.undetectedApps, color: .secondary,
                        unrecordedDuration: summary.unrecordedDuration,
                        total: smallUndetectedDuration)
                        .frame(width: geometry.size.width * smallUndetectedDuration / summary.total)
                        .overlay {
                            Rectangle()
                                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                                .frame(height: 12)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background {
                Capsule()
                    .fill(.primary.opacity(0.08))
                    .frame(height: 8)
            }
        }
        .frame(height: 20)
    }

    private func row(name: String, symbol: String, color: Color, duration: TimeInterval,
                     apps: [CategoryUsageSummary.AppEntry] = [], unrecordedDuration: TimeInterval = 0,
                     showsSmallGroups: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(name)
                Spacer()
                Text(StatisticsDuration.label(duration, locale: locale)).monospacedDigit()
                Text((duration / summary.total).formatted(.percent.precision(.fractionLength(0)).locale(locale)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 38, alignment: .trailing)
            }
            .font(.callout)
            if showsSmallGroups {
                smallCategoriesBar
            } else if apps.isEmpty && unrecordedDuration == 0 {
                ProgressView(value: duration, total: summary.total).tint(color)
                    .accessibilityLabel(name)
            } else {
                segmentedBar(apps: apps, color: color, unrecordedDuration: unrecordedDuration)
            }
        }
    }

    private func segmentedBar(apps: [CategoryUsageSummary.AppEntry], color: Color,
                              unrecordedDuration: TimeInterval, total: TimeInterval? = nil) -> some View {
        let barTotal = total ?? summary.total
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, entry in
                        Rectangle()
                            .fill(color.opacity(index.isMultiple(of: 2) ? 1 : 0.7))
                            .frame(width: geometry.size.width * entry.duration / barTotal)
                            .overlay(alignment: .trailing) {
                                if index < apps.count - 1 || unrecordedDuration > 0 {
                                    Rectangle()
                                        .fill(StatisticsStyle.panelFill(for: colorScheme))
                                        .frame(width: 1)
                                }
                            }
                    }
                    if unrecordedDuration > 0 {
                        Rectangle().fill(color.opacity(0.4))
                            .frame(width: geometry.size.width * unrecordedDuration / barTotal)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 8)
                .background(.primary.opacity(0.08))
                .clipShape(Capsule())
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                HStack(spacing: 0) {
                    ForEach(apps) { entry in
                        CategoryUsageSegment(title: entry.app.name, seconds: entry.duration)
                            .frame(width: geometry.size.width * entry.duration / barTotal)
                    }
                    if unrecordedDuration > 0 {
                        CategoryUsageSegment(title: localizedString("categories.usage.appUnknown", locale: locale),
                                             seconds: unrecordedDuration)
                            .frame(width: geometry.size.width * unrecordedDuration / barTotal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(height: 20)
    }
}

private struct CategoryUsageSegment: View {
    let title: String
    let seconds: TimeInterval
    @State private var isHovered = false
    @Environment(\.locale) private var locale

    private var duration: String {
        StatisticsDuration.label(seconds, locale: locale)
    }

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture { isHovered = true }
            .popover(isPresented: $isHovered, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(duration).font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .fixedSize()
                .environment(\.locale, locale)
            }
            .accessibilityLabel(title)
            .accessibilityValue(duration)
    }
}

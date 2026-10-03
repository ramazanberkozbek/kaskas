import Charts
import SwiftUI

struct UsageDonutCharts: View {
    let summary: CategoryUsageSummary
    let registry: CategoryRegistry
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            UsageDonutCard(title: "stats.apps.title", slices: appSlices, total: summary.total)
            UsageDonutCard(title: "stats.categories.title", slices: categorySlices, total: summary.total)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var appSlices: [UsageDonutSlice] {
        let palette: [Color] = [StatisticsStyle.computerInactive, StatisticsStyle.studying,
                               StatisticsStyle.average, StatisticsStyle.breakTime, .pink, .mint,
                               .orange, .indigo, .teal, .brown]
        // Assign colors by identity so changing duration order doesn't change an app's color.
        let apps = summary.apps
        var slices = apps.map { entry in
            let colorIndex = entry.id.utf8.reduce(0) { ($0 * 31 + Int($1)) % palette.count }
            return UsageDonutSlice(id: entry.id, name: entry.app.name, duration: entry.duration,
                                   color: palette[colorIndex])
        }
        if summary.unrecordedDuration > 0 {
            slices.append(.init(id: "unrecorded", name: localizedString("categories.usage.appUnknown", locale: locale),
                                duration: summary.unrecordedDuration, color: .secondary))
        }
        return slices
    }

    private var categorySlices: [UsageDonutSlice] {
        var slices = summary.entries.map { entry in
            let category = registry.historicalCategory(for: entry.categoryID)
            return UsageDonutSlice(id: entry.id,
                name: category?.localizedName(for: locale) ?? localizedString("categories.usage.deleted", locale: locale),
                duration: entry.duration, color: category?.color ?? .secondary)
        }
        if summary.undetected > 0 {
            slices.append(.init(id: "undetected", name: localizedString("categories.usage.undetected", locale: locale),
                                duration: summary.undetected, color: .secondary))
        }
        return slices
    }
}

private struct UsageDonutSlice: Identifiable {
    let id: String
    let name: String
    let duration: TimeInterval
    let color: Color
}

private struct UsageDonutCard: View {
    let title: LocalizedStringKey
    let slices: [UsageDonutSlice]
    let total: TimeInterval
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @State private var selectedAngle: Double?
    @State private var hoveredID: String?
    @State private var page = 0

    private let pageSize = 4

    private var sortedSlices: [UsageDonutSlice] {
        slices.filter { $0.duration > 0 }.sorted {
            $0.duration == $1.duration ? $0.id < $1.id : $0.duration > $1.duration
        }
    }

    private var pageCount: Int { max(1, (sortedSlices.count + pageSize - 1) / pageSize) }
    private var currentPage: Int { min(page, pageCount - 1) }
    private var visibleSlices: [UsageDonutSlice] {
        Array(sortedSlices.dropFirst(currentPage * pageSize).prefix(pageSize))
    }

    private var selected: UsageDonutSlice? {
        if let hoveredID { return sortedSlices.first { $0.id == hoveredID } }
        guard let selectedAngle else { return nil }
        var end = 0.0
        return sortedSlices.first { slice in
            end += slice.duration
            return selectedAngle < end
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            ZStack {
                if total > 0 {
                    Chart(sortedSlices) { slice in
                        SectorMark(angle: .value("stats.duration", slice.duration),
                                   innerRadius: .ratio(0.72), angularInset: 2)
                            .foregroundStyle(slice.color)
                            .opacity(selected == nil || selected?.id == slice.id ? 1 : 0.35)
                            .cornerRadius(3)
                            .accessibilityLabel(slice.name)
                            .accessibilityValue(detail(for: slice))
                    }
                    .chartLegend(.hidden)
                    .chartAngleSelection(value: $selectedAngle)
                } else {
                    Circle().stroke(.primary.opacity(0.08), lineWidth: 22).padding(14)
                }
                VStack(spacing: 4) {
                    Text(selected?.name ?? localizedString("stats.total", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(StatisticsDuration.label(selected?.duration ?? total, locale: locale))
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 110)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)

            if total > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<pageSize, id: \.self) { index in
                        Group {
                            if index < visibleSlices.count {
                                let slice = visibleSlices[index]
                                usageRow(slice)
                                    .onHover { hoveredID = $0 ? slice.id : nil }
                            } else {
                                Color.clear.accessibilityHidden(true)
                            }
                        }
                        .frame(height: 34, alignment: .top)
                    }
                }
                Divider()
                paginationControls
            } else {
                Text("categories.usage.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SettingsPageLayout.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
        .onChange(of: slices.map { "\($0.id):\($0.duration)" }) { _, _ in
            selectedAngle = nil
            hoveredID = nil
            page = min(page, pageCount - 1)
        }
        .onChange(of: slices.map(\.id)) { _, _ in page = 0 }
        .onChange(of: page) { _, _ in
            selectedAngle = nil
            hoveredID = nil
        }
    }

    private var paginationControls: some View {
        HStack(spacing: 10) {
            Spacer()
            Button { page = currentPage - 1 } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage == 0)
            .accessibilityLabel("stats.usage.previousPage")
            .help(Text("stats.usage.previousPage"))

            Text("\(currentPage + 1) / \(pageCount)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("stats.usage.page")
                .accessibilityValue("\(currentPage + 1) / \(pageCount)")

            Button { page = currentPage + 1 } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPage >= pageCount - 1)
            .accessibilityLabel("stats.usage.nextPage")
            .help(Text("stats.usage.nextPage"))
        }
        .controlSize(.small)
    }

    private func usageRow(_ slice: UsageDonutSlice) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle().fill(slice.color).frame(width: 7, height: 7).padding(.top, 4)
            Text(slice.name)
                .lineLimit(2)
                .help(slice.name)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(StatisticsDuration.label(slice.duration, locale: locale))
                    .fontWeight(.medium)
                Text((total > 0 ? slice.duration / total : 0)
                    .formatted(.percent.precision(.fractionLength(0)).locale(locale)))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .fixedSize()
        }
        .font(.caption)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slice.name)
        .accessibilityValue(detail(for: slice))
    }

    private func detail(for slice: UsageDonutSlice) -> String {
        let share = total > 0 ? slice.duration / total : 0
        return "\(StatisticsDuration.label(slice.duration, locale: locale)), \(share.formatted(.percent.precision(.fractionLength(0)).locale(locale)))"
    }
}

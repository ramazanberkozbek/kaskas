import SwiftUI

struct StatisticsChartSection<Content: View>: View {
    struct LegendItem: Identifiable {
        let color: Color
        let labelKey: String
        var id: String { "\(labelKey)-\(color.description)" }

        init(_ color: Color, _ labelKey: String) {
            self.color = color
            self.labelKey = labelKey
        }
    }

    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var legend: [LegendItem] = []
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        legend: [(Color, String)] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.legend = legend.map { LegendItem($0.0, $0.1) }
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 14) {
                content
                if !legend.isEmpty {
                    Divider()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(legend) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 7, height: 7)
                                    Text(LocalizedStringKey(item.labelKey))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(SettingsPageLayout.cardInset)
            .background(StatisticsStyle.panelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.09)))
        }
    }
}

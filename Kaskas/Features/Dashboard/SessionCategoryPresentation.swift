import SwiftUI

struct SessionCategoryPresentation {
    let title: String
    let symbol: String
    let color: Color
    let explanation: String
    let mixedBreakdown: String?

    init(selection: SessionCategorySelection, summary: StudySessionCategorySummary,
         registry: CategoryRegistry, isOngoing: Bool) {
        mixedBreakdown = {
            guard selection == .automatic, summary.decision == .mixed else { return nil }
            return summary.usage.entries.prefix(2).map { entry in
                let name = registry.historicalCategory(for: entry.categoryID)?.name
                    ?? String(localized: "categories.usage.deleted")
                let percentage = (entry.duration / summary.usage.total).formatted(.percent.precision(.fractionLength(0)))
                return "\(name) \(percentage)"
            }.joined(separator: " · ")
        }()
        switch selection {
        case .category(let id):
            let category = registry.historicalCategory(for: id)
            title = category?.name ?? String(localized: "categories.usage.deleted")
            symbol = category?.iconName ?? "tag"
            color = category?.color ?? .secondary
            explanation = String(localized: "dashboard.session.category.manual")
        case .legacy(let label):
            title = label.isEmpty ? String(localized: "dashboard.session.category.manual") : label
            symbol = "tag"
            color = .secondary
            explanation = String(localized: "dashboard.session.category.manual")
        case .automatic:
            switch summary.decision {
            case .dominant(let id):
                let category = registry.historicalCategory(for: id)
                title = category?.name ?? String(localized: "categories.usage.deleted")
                symbol = category?.iconName ?? "tag"
                color = category?.color ?? .secondary
                let duration = summary.usage.entries.first { $0.categoryID == id }?.duration ?? 0
                let percentage = (duration / summary.usage.total).formatted(.percent.precision(.fractionLength(0)))
                explanation = String(format: String(localized: "dashboard.session.category.share"), percentage)
            case .mixed:
                title = String(localized: "dashboard.session.category.mixed")
                symbol = "square.stack.3d.up"
                color = .secondary
                explanation = String(localized: "dashboard.session.category.mixedExplanation")
            case .insufficient(let reason):
                title = String(localized: "dashboard.session.category.undetermined")
                symbol = "questionmark.circle"
                color = .secondary
                explanation = reason == .tooShort && isOngoing
                    ? String(localized: "dashboard.session.category.collecting")
                    : String(localized: "dashboard.session.category.lowCoverage")
            }
        }
    }
}

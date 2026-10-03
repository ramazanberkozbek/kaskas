import SwiftUI

struct SessionCategoryPresentation {
    let title: String
    let symbol: String
    let color: Color
    let explanation: String
    let mixedBreakdown: String?

    init(selection: SessionCategorySelection, summary: StudySessionCategorySummary,
         registry: CategoryRegistry, isOngoing: Bool, locale: Locale = AppLanguage.currentLocale) {
        mixedBreakdown = {
            guard selection == .automatic, summary.decision == .mixed, summary.usage.total > 0 else { return nil }
            return summary.usage.entries.prefix(2).map { entry in
                let name = registry.historicalCategory(for: entry.categoryID)?.localizedName(for: locale)
                    ?? localizedString("categories.usage.deleted", locale: locale)
                let percentage = (entry.duration / summary.usage.total).formatted(.percent.precision(.fractionLength(0)).locale(locale))
                return "\(name) \(percentage)"
            }.joined(separator: " · ")
        }()
        switch selection {
        case .category(let id):
            let category = registry.historicalCategory(for: id)
            title = category?.localizedName(for: locale) ?? localizedString("categories.usage.deleted", locale: locale)
            symbol = category?.iconName ?? "tag"
            color = category?.color ?? .secondary
            explanation = localizedString("dashboard.session.category.manual", locale: locale)
        case .legacy(let label):
            title = label.isEmpty ? localizedString("dashboard.session.category.manual", locale: locale) : label
            symbol = "tag"
            color = .secondary
            explanation = localizedString("dashboard.session.category.manual", locale: locale)
        case .automatic:
            switch summary.decision {
            case .dominant(let id):
                let category = registry.historicalCategory(for: id)
                title = category?.localizedName(for: locale) ?? localizedString("categories.usage.deleted", locale: locale)
                symbol = category?.iconName ?? "tag"
                color = category?.color ?? .secondary
                let duration = summary.usage.entries.first { $0.categoryID == id }?.duration ?? 0
                let total = summary.usage.total
                let percentage = total > 0 ? (duration / total).formatted(.percent.precision(.fractionLength(0)).locale(locale)) : "0%"
                explanation = String(format: localizedString("dashboard.session.category.share", locale: locale), percentage)
            case .mixed:
                title = localizedString("dashboard.session.category.mixed", locale: locale)
                symbol = "square.stack.3d.up"
                color = .secondary
                explanation = localizedString("dashboard.session.category.mixedExplanation", locale: locale)
            case .insufficient(let reason):
                title = localizedString("dashboard.session.category.undetermined", locale: locale)
                symbol = "questionmark.circle"
                color = .secondary
                explanation = reason == .tooShort && isOngoing
                    ? localizedString("dashboard.session.category.collecting", locale: locale)
                    : localizedString("dashboard.session.category.lowCoverage", locale: locale)
            }
        }
    }
}

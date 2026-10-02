import Foundation

nonisolated enum SessionCategorySelection: Hashable, Sendable {
    case automatic
    case category(id: String)
    case legacy(label: String)

    init(annotation: SessionAnnotation) {
        if let id = annotation.categoryID {
            self = .category(id: id)
        } else if !annotation.category.isEmpty {
            self = .legacy(label: annotation.category)
        } else {
            self = .automatic
        }
    }
}

nonisolated enum SessionCategoryDecision: Equatable, Sendable {
    enum InsufficientReason: Equatable, Sendable {
        case tooShort, lowCoverage
    }

    case dominant(categoryID: String)
    case mixed
    case insufficient(InsufficientReason)
}

/// Session labels describe the recorded distribution; they never reassign its minutes.
nonisolated struct StudySessionCategorySummary: Equatable, Sendable {
    struct Policy: Equatable, Sendable {
        var minimumDuration: TimeInterval = 60
        var minimumCoverage = 0.50
        var minimumDominantShare = 0.50
        var minimumLead = 0.20
    }

    let usage: CategoryUsageSummary
    let decision: SessionCategoryDecision

    init(usage: CategoryUsageSummary, policy: Policy = Policy()) {
        self.usage = usage
        guard usage.total >= policy.minimumDuration,
              usage.resolvedDuration >= policy.minimumDuration else {
            decision = .insufficient(.tooShort)
            return
        }
        guard usage.resolvedDuration >= usage.total * policy.minimumCoverage else {
            decision = .insufficient(.lowCoverage)
            return
        }
        guard let first = usage.entries.first else {
            decision = .insufficient(.lowCoverage)
            return
        }
        let secondDuration = usage.entries.dropFirst().first?.duration ?? 0
        let dominantDuration = first.categoryID == "other" ? first.resolvedDuration : first.duration
        if dominantDuration >= usage.total * policy.minimumDominantShare,
           first.duration - secondDuration >= usage.total * policy.minimumLead {
            decision = .dominant(categoryID: first.categoryID)
        } else {
            decision = .mixed
        }
    }
}

#if DEBUG
import SwiftUI

enum SessionDebugFormat {
    // Keep the existing diagnostic notation, with one formatter per process.
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let secondsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    static func rawSeconds(_ duration: TimeInterval) -> String {
        secondsFormatter.string(from: NSNumber(value: duration)) ?? duration.description
    }

    static func minutesAndSeconds(_ duration: TimeInterval) -> String {
        let wholeSeconds = Int(max(0, duration))
        return String(format: "%02d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }

    static func duration(_ duration: TimeInterval) -> String {
        "\(minutesAndSeconds(duration)) (\(rawSeconds(duration)) sn)"
    }
}

struct SessionDebugGap {
    let start: Date
    let end: Date

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    var splitsSession: Bool { duration >= StudySessionGrouping.maximumInterruption }
    var countsAsInterruption: Bool { duration >= StudySessionGrouping.minimumCountedInterruption }

    func fillers(in intervals: [ActivityInterval]) -> [ActivityInterval] {
        intervals.filter {
            $0.kind != .studying && $0.startedAt < end && $0.endedAt > start
        }.sorted { $0.startedAt < $1.startedAt }
    }

    func decisionText(breakEntries: [BreakHistoryEntry] = []) -> String {
        if breakEntries.contains(where: { entry in
            guard entry.isSessionBoundary, let breakStart = entry.startedAt else { return false }
            return breakStart >= start && entry.occurredAt <= end
        }) {
            return "\(SessionDebugFormat.rawSeconds(duration)) sn · gerçek mola → böldü"
        }
        let sign = splitsSession ? "≥" : "<"
        let decision = splitsSession ? "böldü" : "birleşti"
        return "\(SessionDebugFormat.rawSeconds(duration)) sn \(sign) \(Int(StudySessionGrouping.maximumInterruption)) → \(decision)"
    }
}

enum SessionDebugInspection {
    static func gap(before index: Int, in session: StudySession) -> SessionDebugGap? {
        guard index > 0, index < session.intervals.count,
              let previousEnd = session.intervals[..<index].map(\.endedAt).max() else { return nil }
        let start = session.intervals[index].startedAt
        guard start >= previousEnd else { return nil }
        return SessionDebugGap(start: previousEnd, end: start)
    }

    static func boundary(after session: StudySession, next: StudySession?) -> SessionDebugGap? {
        guard let next, next.startedAt > session.endedAt else { return nil }
        return SessionDebugGap(start: session.endedAt, end: next.startedAt)
    }

    static func endingKind(of interval: ActivityInterval, in allIntervals: [ActivityInterval]) -> String {
        if let next = allIntervals
            .filter({ $0.kind != .studying
                && $0.startedAt <= interval.endedAt.addingTimeInterval(0.5)
                && $0.endedAt >= interval.endedAt.addingTimeInterval(-0.5) })
            .min(by: { abs($0.startedAt.timeIntervalSince(interval.endedAt))
                < abs($1.startedAt.timeIntervalSince(interval.endedAt)) }) {
            return next.kind.rawValue
        }
        if allIntervals.contains(where: {
            $0.kind == .studying && $0.id != interval.id
                && $0.startedAt <= interval.endedAt && $0.endedAt >= interval.endedAt
        }) {
            return "studying (çakışan parça)"
        }
        return "bilgi yok"
    }

    static func overlaps(of index: Int, in session: StudySession) -> [String] {
        let interval = session.intervals[index]
        return session.intervals.enumerated().compactMap { otherIndex, other in
            guard otherIndex != index else { return nil }
            let duration = min(interval.endedAt, other.endedAt)
                .timeIntervalSince(max(interval.startedAt, other.startedAt))
            guard duration > 0 else { return nil }
            return "#\(otherIndex + 1): \(SessionDebugFormat.rawSeconds(duration)) sn"
        }
    }
}

struct DashboardSessionDebugRow: View {
    let session: StudySession
    let allIntervals: [ActivityInterval]
    let nextSession: StudySession?
    let isHiddenByShortFilter: Bool
    let breakEntries: [BreakHistoryEntry]

    var body: some View {
        let elapsed = session.endedAt.timeIntervalSince(session.startedAt)
        let empty = elapsed - session.focusedDuration
        VStack(alignment: .leading, spacing: 3) {
            Text("\(SessionDebugFormat.clock(session.startedAt))–\(SessionDebugFormat.clock(session.endedAt))")
            Text("odak \(SessionDebugFormat.duration(session.focusedDuration)) · geçen \(SessionDebugFormat.duration(elapsed)) · boşluk \(SessionDebugFormat.duration(empty))")
            Text("ham parça \(session.intervals.count) · kesinti \(session.interruptionCount)")
            if let gap = SessionDebugInspection.boundary(after: session, next: nextSession) {
                let kinds = gap.fillers(in: allIntervals).map { $0.kind.rawValue }
                let entries = entries(in: gap)
                Text("bitiş: boşluk \(SessionDebugFormat.rawSeconds(gap.duration)) sn · \(kinds.isEmpty ? "tür: bilgi yok" : kinds.joined(separator: ", "))")
                Text("karar: \(gap.decisionText(breakEntries: entries)) · mola: \(breakSummary(entries))")
            } else if let lastInterval = session.intervals.last {
                let ending = SessionDebugInspection.endingKind(of: lastInterval, in: allIntervals)
                Text("bitiş: sonraki seans yok · bitiş sonrası kayıt: \(ending)")
            }
            if isHiddenByShortFilter {
                Text("gizli: odakta < 5 dk")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }

    private func entries(in gap: SessionDebugGap) -> [BreakHistoryEntry] {
        breakEntries.filter { $0.occurredAt >= gap.start && $0.occurredAt < gap.end.addingTimeInterval(0.001) }
    }

    private func breakSummary(_ entries: [BreakHistoryEntry]) -> String {
        return entries.isEmpty ? "bilgi yok" : entries.map(\.debugDescription).joined(separator: "; ")
    }
}

struct SessionDebugDetailView: View {
    let session: StudySession
    let allIntervals: [ActivityInterval]
    let nextSession: StudySession?
    let controller: SessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider()
            Text("Oturum ayrıntıları (debug)").fontWeight(.semibold)
            Text("not anahtarı: \(session.id) · ilk parça \(SessionDebugFormat.clock(session.startedAt))")
            ForEach(transferredNotes, id: \.key) { source in
                Text("taşınan not: \(SessionDebugFormat.clock(source.date)) [\(source.key)] \(source.note)")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(session.intervals.indices, id: \.self) { index in
                        if let gap = SessionDebugInspection.gap(before: index, in: session) {
                            gapBlock(gap, title: "Parçalar arası boşluk")
                        }
                        pieceBlock(index)
                    }
                    if let gap = SessionDebugInspection.boundary(after: session, next: nextSession) {
                        gapBlock(gap, title: "Sonraki seansa kadar")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 300)
        }
        .font(.system(size: 10, design: .monospaced))
        .textSelection(.enabled)
    }

    private var transferredNotes: [(key: String, date: Date, note: String)] {
        var seen: Set<String> = [session.id]
        return session.intervals.compactMap { interval in
            guard seen.insert(interval.sessionKey).inserted else { return nil }
            let note = controller.annotation(for: interval).note
            guard !note.isEmpty else { return nil }
            return (interval.sessionKey, interval.startedAt, note)
        }
    }

    private func pieceBlock(_ index: Int) -> some View {
        let interval = session.intervals[index]
        let overlap = SessionDebugInspection.overlaps(of: index, in: session)
        let isLive = controller.activeStudyingStartedAt == interval.startedAt
        return VStack(alignment: .leading, spacing: 3) {
            Text("#\(index + 1) \(SessionDebugFormat.clock(interval.startedAt))–\(SessionDebugFormat.clock(interval.endedAt)) · \(SessionDebugFormat.duration(interval.endedAt.timeIntervalSince(interval.startedAt)))")
                .fontWeight(.semibold)
            Text("bitiş sonrası kayıt: \(SessionDebugInspection.endingKind(of: interval, in: allIntervals)) · \(isLive ? "canlı" : "tamamlandı")")
            if !overlap.isEmpty {
                Text("çakışma: \(overlap.joined(separator: ", ")) · süre union ile sayıldı")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
    }

    private func gapBlock(_ gap: SessionDebugGap, title: String) -> some View {
        let fillers = gap.fillers(in: allIntervals)
        let entries = controller.breakEntries(from: gap.start, through: gap.end)
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(title): \(SessionDebugFormat.clock(gap.start))–\(SessionDebugFormat.clock(gap.end)) · \(SessionDebugFormat.duration(gap.duration))")
                .fontWeight(.semibold)
            if fillers.isEmpty {
                Text("boşluğu dolduran kayıt: bilgi yok")
            } else {
                ForEach(fillers) { interval in
                    Text("↳ \(interval.kind.rawValue) · \(SessionDebugFormat.duration(interval.endedAt.timeIntervalSince(interval.startedAt))) · \(SessionDebugFormat.clock(interval.startedAt))–\(SessionDebugFormat.clock(interval.endedAt))")
                }
            }
            Text("karar: \(gap.decisionText(breakEntries: entries))")
            Text(gap.countsAsInterruption ? "kesinti sayıldı (≥ 30 sn)" : "sayılmadı (artefakt, < 30 sn)")
            Text("mola kaydı: \(entries.isEmpty ? "bilgi yok" : entries.map(\.debugDescription).joined(separator: "; "))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 4))
    }
}

private extension BreakHistoryEntry {
    var debugDescription: String {
        let result = outcome == .skipped ? "skip" : "tamamlandı"
        switch source {
        case .smartPause:
            return "kabul edilmiş hareketsizlik molası · \(result)"
        case .scheduled:
            return "planlı mola · \(result) · kısa/uzun: bilgi yok"
        case .manual:
            return "kaynak manual (kullanıcı işlemi) · \(result) · kısa/uzun: bilgi yok"
        }
    }
}
#endif

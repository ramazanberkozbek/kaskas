import SwiftUI

struct SessionDetailView: View {
    let session: StudySession
    let controller: SessionController
    let summary: StudySessionCategorySummary
    let allIntervals: [ActivityInterval]
    let nextSession: StudySession?
    let onSave: (() -> Void)?

    @State private var categorySelection: SessionCategorySelection
    @State private var note: String
    @Environment(\.dismiss) private var dismiss
#if DEBUG
    @AppStorage(DebugPreferences.Key.modeEnabled, store: DebugPreferences.store) private var debugModeEnabled = false
    @AppStorage(DebugPreferences.Key.sessionDetailsEnabled, store: DebugPreferences.store) private var debugSessionDetailsEnabled = false
#endif

    init(session: StudySession, controller: SessionController, summary: StudySessionCategorySummary,
         allIntervals: [ActivityInterval], nextSession: StudySession?, onSave: (() -> Void)? = nil) {
        self.session = session
        self.controller = controller
        self.summary = summary
        self.allIntervals = allIntervals
        self.nextSession = nextSession
        self.onSave = onSave
        let annotation = controller.annotation(for: session)
        _categorySelection = State(initialValue: .init(annotation: annotation))
        _note = State(initialValue: annotation.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Text("dashboard.session.detail")
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.startedAt.formatted(.dateTime.day().month(.abbreviated).locale(controller.locale)))
                    Text("\(session.startedAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(controller.locale))) – \(session.endedAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(controller.locale)))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
            }
            ViewThatFits(in: .vertical) {
                detailContent.fixedSize(horizontal: false, vertical: true)
                ScrollView { detailContent }
                    .scrollIndicators(.hidden)
            }
            HStack {
                Spacer()
                Button("dashboard.session.cancel") { dismiss() }
                Button("dashboard.session.save") {
                    let selection: SessionCategorySelection
                    if case .legacy(let label) = categorySelection {
                        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                        selection = trimmed.isEmpty ? .automatic : .legacy(label: trimmed)
                    } else {
                        selection = categorySelection
                    }
                    controller.save(categorySelection: selection,
                        note: note.trimmingCharacters(in: .whitespacesAndNewlines), for: session)
                    onSave?()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: detailWidth)
        .frame(maxHeight: 680)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            categoryEditor
            CategoryUsageView(summary: summary.usage, registry: controller.categoryRegistry,
                storageFailed: controller.appUsage.storageFailed,
                title: "dashboard.session.category.distribution",
                subtitle: "dashboard.session.category.distributionExplanation",
                showsAppSegments: true)
            noteEditor
#if DEBUG
            if debugModeEnabled && debugSessionDetailsEnabled {
                SessionDebugDetailView(session: session, allIntervals: allIntervals,
                    nextSession: nextSession, controller: controller)
            }
#endif
        }
    }

    private var categoryEditor: some View {
        let categorySummary = summary
        let isOngoing = session.isOngoing(startedAt: controller.activeStudyingStartedAt)
        let presentation = SessionCategoryPresentation(selection: categorySelection, summary: categorySummary,
            registry: controller.categoryRegistry,
            isOngoing: isOngoing,
            locale: controller.locale)
        let detectedCategory = SessionCategoryPresentation(selection: .automatic, summary: categorySummary,
            registry: controller.categoryRegistry, isOngoing: isOngoing, locale: controller.locale)
        return VStack(alignment: .leading, spacing: 8) {
            Picker("dashboard.session.category", selection: $categorySelection) {
                Label(detectedCategory.title, systemImage: detectedCategory.symbol)
                    .tag(SessionCategorySelection.automatic)
                ForEach(controller.categoryRegistry.categories) { category in
                    Label(category.localizedName(for: controller.locale), systemImage: category.iconName)
                        .tag(SessionCategorySelection.category(id: category.id))
                }
                // Keep a saved hidden/deleted category selectable without reviving it for app rules.
                if case .category(let id) = categorySelection,
                   !controller.categoryRegistry.categories.contains(where: { $0.id == id }) {
                    Text(presentation.title).tag(categorySelection)
                }
                if case .legacy = categorySelection {
                    Text(presentation.title).tag(categorySelection)
                }
            }
            .pickerStyle(.menu)
            if categorySelection == .automatic,
               isOngoing {
                Text("dashboard.session.category.provisional").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("dashboard.session.note").font(.subheadline.weight(.medium))
            TextEditor(text: $note)
                .font(.body)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(8)
                .frame(height: 130)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.12)))
                .accessibilityLabel(Text("dashboard.session.note"))
        }
    }

    private var detailWidth: CGFloat {
#if DEBUG
        debugModeEnabled && debugSessionDetailsEnabled ? 620 : 480
#else
        480
#endif
    }
}

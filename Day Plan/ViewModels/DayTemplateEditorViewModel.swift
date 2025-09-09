import Foundation
import SwiftData

/// MVVM for `DayTemplateEditorView`.
/// Owns "create vs edit" flow, drafts, clamping, and persistence.
@MainActor
final class DayTemplateEditorViewModel: ObservableObject {

    // Mirrors the view's modes but stores identifiers instead of objects where possible.
    enum Mode {
        case create(prefillName: String?, onSaved: ((DayTemplate) -> Void)?)
        case edit(templateID: UUID)
    }

    // MARK: - Inputs

    private(set) var mode: Mode
    private weak var modelContext: ModelContext?

    // MARK: - State (Create mode)
    @Published var name: String = ""
    @Published var drafts: [PlanEntryDraft] = []

    // Used by the view to trigger a list refresh after mutations.
    @Published var refreshID = UUID()

    // MARK: - Init / Attach

    /// ViewModel initializer that accepts the view's public Mode and maps it
    /// into a VM-internal, persistence-friendly Mode (IDs instead of objects).
    init(mode: DayTemplateEditorView.Mode) {
        switch mode {
        case .create(let prefill, let onSaved):
            self.mode = .create(prefillName: prefill, onSaved: onSaved)
            self.name = prefill ?? ""
        case .edit(let template):
            self.mode = .edit(templateID: template.id)
        }
    }

    /// Provide model context after the view has access to `@Environment(\.modelContext)`.
    func attach(context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Read

    /// Anchor day:
    /// - Create: earliest draft (anchored), or today 00:00.
    /// - Edit: earliest plan or the template's own `dayStart`.
    var anchorDay: Date {
        switch mode {
        case .create:
            let fallback = Calendar.current.startOfDay(for: .now)
            let earliest =
                drafts
                .map { TimeUtil.anchoredTime($0.start, to: fallback) }
                .min()
            return earliest ?? fallback

        case .edit(let templateID):
            guard
                let ctx = modelContext,
                let tpl = ctx.dayTemplate(with: templateID)
            else {
                return Calendar.current.startOfDay(for: .now)
            }
            return tpl.dayStart
        }
    }

    /// Suggest next start time = end of last block (create: draft, edit: scheduled).
    func suggestedInitialStart() -> Date {
        let anchor = anchorDay
        let endOfDay = anchor.addingTimeInterval(24 * 60 * 60)

        let lastEnd: Date = {
            switch mode {
            case .create:
                return drafts.map { d -> Date in
                    let start = TimeUtil.anchoredTime(d.start, to: anchor)
                    let clamped = clampMinutes(
                        start: start, requestedMinutes: d.lengthMinutes)
                    return start.addingTimeInterval(TimeInterval(clamped * 60))
                }.max() ?? anchor

            case .edit(let templateID):
                guard let ctx = modelContext else { return anchor }
                return ctx.scheduledPlans(for: templateID)
                    .map { $0.startTime.addingTimeInterval($0.duration) }
                    .max() ?? anchor
            }
        }()

        return min(lastEnd, endOfDay.addingTimeInterval(-60))
    }

    // MARK: - Write (Create)

    /// Add a new draft block in create mode.
    func appendDraft(plan: Plan, start: Date, lengthMinutes: Int) {
        let anchoredStart = TimeUtil.anchoredTime(start, to: anchorDay)
        let clamped = clampMinutes(
            start: anchoredStart, requestedMinutes: lengthMinutes)
        drafts.append(
            PlanEntryDraft(
                existingPlan: plan, start: anchoredStart, lengthMinutes: clamped
            ))
        refreshID = UUID()
    }

    /// Persist the new template with all current drafts.
    func saveTemplateCreate() -> DayTemplate? {
        guard case .create(_, let onSaved) = mode, let ctx = modelContext else {
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tpl = DayTemplate(name: trimmed.isEmpty ? "New Day" : trimmed)
        ctx.insert(tpl)

        let saveAnchor = anchorDay
        for d in drafts {
            guard let plan = ctx.plan(with: d.planID) else { continue }
            let start = TimeUtil.anchoredTime(d.start, to: saveAnchor)
            let minutes = clampMinutes(
                start: start, requestedMinutes: d.lengthMinutes)
            let sp = ScheduledPlan(
                plan: plan, startTime: start,
                duration: TimeInterval(minutes * 60))
            sp.dayTemplate = tpl
            ctx.insert(sp)
        }

        try? ctx.save()
        onSaved?(tpl)
        return tpl
    }

    /// Remove drafts at list offsets (sorted by anchored time for stable UX).
    func deleteDrafts(at offsets: IndexSet) {
        var arr = sortedDrafts()
        for i in offsets {
            let d = arr[i]
            if let idx = drafts.firstIndex(where: { $0.id == d.id }) {
                drafts.remove(at: idx)
            }
        }
    }

    func sortedDrafts() -> [PlanEntryDraft] {
        drafts.sorted {
            TimeUtil.anchoredTime($0.start, to: anchorDay)
                < TimeUtil.anchoredTime($1.start, to: anchorDay)
        }
    }

    // MARK: - Write (Edit)

    /// Add a scheduled plan directly to an existing template.
    func addScheduled(
        to templateID: UUID, plan: Plan, start: Date, lengthMinutes: Int
    ) {
        guard let ctx = modelContext else { return }
        let anchoredStart = TimeUtil.anchoredTime(start, to: anchorDay)
        let minutes = clampMinutes(
            start: anchoredStart, requestedMinutes: lengthMinutes)
        let sp = ScheduledPlan(
            plan: plan, startTime: anchoredStart,
            duration: TimeInterval(minutes * 60))
        sp.dayTemplate = ctx.dayTemplate(with: templateID)
        ctx.insert(sp)
        try? ctx.save()
        refreshID = UUID()
    }

    func updateScheduled(
        _ sp: ScheduledPlan, newStart: Date? = nil, newMinutes: Int? = nil
    ) {
        guard let ctx = modelContext else { return }
        let startAnchor = anchorDay
        if let s = newStart {
            let anchored = TimeUtil.anchoredTime(s, to: startAnchor)
            sp.startTime = anchored
        }
        if let m = newMinutes {
            let anchored = TimeUtil.anchoredTime(sp.startTime, to: startAnchor)
            let minutes = clampMinutes(start: anchored, requestedMinutes: m)
            sp.startTime = anchored
            sp.duration = TimeInterval(minutes * 60)
        }
        try? ctx.save()
    }

    func deleteScheduled(at offsets: IndexSet, from template: DayTemplate) {
        guard let ctx = modelContext else { return }
        let sorted = template.scheduledPlans.sorted {
            $0.startTime < $1.startTime
        }
        for idx in offsets { ctx.delete(sorted[idx]) }
        try? ctx.save()
    }

    // MARK: - Utilities

    /// Clamp a requested duration (minutes) so that `start + duration` stays within the same day.
    func clampMinutes(start: Date, requestedMinutes: Int) -> Int {
        DayScheduleEngine.clampDurationWithinDay(
            start: start,
            requestedMinutes: requestedMinutes,
            day: DayWindow(start: anchorDay)
        )
    }

    /// Maximum minutes allowed from a given `start` until the end of the 24h window.
    /// The view uses this to **limit** pickers so overflow is impossible.
    func maxSelectableMinutes(from start: Date) -> Int {
        let end = anchorDay.addingTimeInterval(24 * 60 * 60)
        return max(0, Int(end.timeIntervalSince(start) / 60))
    }

    /// Live fetch of a `Plan` if it still exists (useful for showing "Deleted" labels).
    func livePlan(for id: UUID) -> Plan? {
        guard let ctx = modelContext else { return nil }
        return ctx.plan(with: id)
    }
}

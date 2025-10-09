import SwiftData
import SwiftUI

/// Card-only rendering for a scheduled plan row (no spine drawing).
struct TimelineCardOnlyRow: View {
    // Inputs
    let sp: ScheduledPlan
    let isFirst: Bool
    let isLast: Bool
    let now: Date
    let isEditing: Bool
    let editMinuteHeight: CGFloat
    /// If true, keeps the left gutter equal to the spine column width so layout matches when spines overlay.
    let reserveGutter: Bool

    // VM
    @StateObject private var vm: TimelineSpineRowViewModel

    // Anim state
    @State private var displayedProgress: Double = 0
    @State private var isCollapsing = false
    @State private var currentGutter: CGFloat = 0

    init(
        sp: ScheduledPlan,
        isFirst: Bool,
        isLast: Bool,
        now: Date,
        isEditing: Bool,
        editMinuteHeight: CGFloat,
        reserveGutter: Bool
    ) {
        self.sp = sp
        self.isFirst = isFirst
        self.isLast = isLast
        self.now = now
        self.isEditing = isEditing
        self.editMinuteHeight = editMinuteHeight
        self.reserveGutter = reserveGutter
        _vm = StateObject(wrappedValue: TimelineSpineRowViewModel(sp: sp))
    }

    // Derived
    private var start: Date { sp.startTime }
    private var end: Date { sp.endTime }
    private var status: TimelineSpineRowViewModel.Status { vm.status(now: now) }
    private var liveProgress: Double { vm.liveProgress(now: now) }
    private var planTint: Color { sp.plan?.tintColor ?? .accentColor }

    private var durationMinutes: Int { max(0, Int(sp.duration / 60)) }
    private var editExactHeight: CGFloat {
        CGFloat(durationMinutes) * editMinuteHeight
    }
    private var cardHeight: CGFloat {
        isEditing ? editExactHeight : TimelineStyle.viewModeRowHeight
    }

    private var keepGutterSpace: Bool { reserveGutter }
    private var totalGutter: CGFloat {
        TimelineStyle.leftColumnWidth + TimelineStyle.gapWidth
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(sp.plan?.title ?? "Untitled")
                    .font(.headline)

                Text(vm.timeRangeString())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .opacity(isEditing ? 0 : 1)

                if status == .current {
                    ProgressView(value: displayedProgress)
                        .progressViewStyle(.linear)
                        .tint(planTint)
                        .animation(
                            isCollapsing ? nil : .linear(duration: 0.6),
                            value: displayedProgress
                        )
                        .blur(radius: isCollapsing ? 1.2 : 0)
                        .opacity(isEditing ? 0 : 1)

                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)

            if status == .current {
                HStack(spacing: 4) { Text("Now") }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(planTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(planTint.opacity(0.16), in: Capsule())
                    .overlay(
                        Capsule().stroke(planTint.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: planTint.opacity(0.25), radius: 3, y: 1)
                    .opacity(isEditing ? 0 : 1)

                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: cardHeight, alignment: .top)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .opacity(status == .past ? 0.6 : 1)
        .padding(.vertical, isEditing ? 0 : TimelineStyle.cardVerticalPadView)
        .padding(.leading, currentGutter)
        .animation(
            .easeInOut(duration: TimelineStyle.gutterAnimationDuration),
            value: currentGutter
        )
        .animation(repositionAnimation, value: isEditing)
        .onAppear {
            currentGutter = keepGutterSpace ? totalGutter : 0
            displayedProgress = liveProgress
        }
        .onChange(of: liveProgress) { new in
            if isCollapsing {
                displayedProgress = new
            } else {
                withAnimation(
                    .linear(duration: TimelineStyle.progressAnimDuration)
                ) {
                    displayedProgress = new
                }
            }
        }
        .onChange(of: reserveGutter) { _ in
            isCollapsing = true
            withAnimation(
                .easeInOut(duration: TimelineStyle.gutterAnimationDuration)
            ) {
                currentGutter = keepGutterSpace ? totalGutter : 0
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + TimelineStyle.gutterCollapseDelay
            ) {
                isCollapsing = false
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var repositionAnimation: Animation {
        isEditing
            ? .easeInOut(duration: TimelineStyle.cardRepositionDuration)
            : .easeInOut(duration: TimelineStyle.generic(0.28))
    }

    private var accessibilityText: Text {
        let title = Text(sp.plan?.title ?? "Untitled")
        let time = Text(
            "\(start.formatted(date: .omitted, time: .shortened)) to \(end.formatted(date: .omitted, time: .shortened))"
        )
        let state: Text = {
            switch status {
            case .past: return Text("Completed")
            case .current: return Text("In progress")
            case .upcoming: return Text("Scheduled")
            }
        }()
        return title + Text(". ") + state + Text(". ") + time
    }
}

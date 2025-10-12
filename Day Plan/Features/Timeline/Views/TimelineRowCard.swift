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

    // --- Edit-mode interaction state (UI-only preview; not persisted) ---
    @GestureState private var dragTranslationY: CGFloat = 0
    @GestureState private var resizeBottomTranslationY: CGFloat = 0

    // Drag/move state
    @State private var baseOffsetMinutes: Int = 0        // accumulated committed move delta
    @State private var proposedOffsetMinutes: Int = 0    // live preview while dragging

    // Bottom-resize state
    @State private var baseBottomDeltaMinutes: Int = 0   // accumulated committed resize delta
    @State private var proposedBottomDeltaMinutes: Int = 0 // live preview while resizing
    @State private var liveResizePoints: CGFloat = 0 // continuous, unsnapped drag distance (points) during resize

    @State private var isInteracting: Bool = false

    private let minDurationMinutes: Int = 5 // UX: keep cards at least 5 minutes tall

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

    /// Exact edit height derived from duration.
    private var editExactHeight: CGFloat { CGFloat(durationMinutes) * editMinuteHeight }

    /// Card height reflects live resize preview in Edit, fixed row in View.
    private var cardHeight: CGFloat {
        if isEditing {
            return CGFloat(visualDurationMinutesDouble) * editMinuteHeight
        } else {
            return TimelineStyle.viewModeRowHeight
        }
    }

    private var keepGutterSpace: Bool { reserveGutter }
    private var totalGutter: CGFloat { TimelineStyle.leftColumnWidth + TimelineStyle.gapWidth }

    // MARK: - Edit preview helpers

    /// Snap vertically to whole-minute steps; preserves sign for up/down.
    private func snapToMinutes(_ dy: CGFloat) -> Int {
        // Stable quantization: truncate toward zero so we only step
        // when the pointer crosses a full minute boundary. This avoids
        // oscillating around 0.5-step thresholds during drags.
        let raw = dy / editMinuteHeight
        return Int(raw.rounded(.towardZero))
    }

    /// Proposed vertical offset (in minutes) while moving in Edit.
    private var visualOffsetMinutes: Int {
        guard isEditing else { return 0 }
        return proposedOffsetMinutes
    }

    /// Proposed duration (as Double minutes) while resizing in Edit; enforces a minimum.
    private var visualDurationMinutesDouble: Double {
        guard isEditing else { return Double(durationMinutes) }
        let base = Double(durationMinutes + baseBottomDeltaMinutes)
        let live = Double(liveResizePoints / editMinuteHeight)
        let combined = base + live
        return max(Double(minDurationMinutes), combined)
    }
    /// Integer minutes helper for date previews.
    private var visualDurationMinutes: Int { Int(visualDurationMinutesDouble.rounded(.towardZero)) }

    private var previewStart: Date {
        Calendar.current.date(byAdding: .minute, value: visualOffsetMinutes, to: start) ?? start
    }
    private var previewEnd: Date {
        Calendar.current.date(byAdding: .minute, value: visualDurationMinutes, to: previewStart) ?? end
    }

    /// Layout padding adjustment that keeps the stack footprint at the baseline while resizing (Edit only).
    /// If the card grows, we use negative padding (overlap). If it shrinks, we add positive padding
    /// equal to the lost height so rows below never get pulled up.
    private var editPaddingAdjustment: CGFloat {
        guard isEditing else { return 0 }
        let deltaMinutes = visualDurationMinutesDouble - Double(durationMinutes)
        // positive delta (extended) -> negative padding; negative delta (shrunk) -> positive padding
        return CGFloat(-deltaMinutes) * editMinuteHeight
    }

    // MARK: - Body

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

            // Floating time HUD for edit interactions
            if isEditing && isInteracting {
                Text("\(previewStart.formatted(date: .omitted, time: .shortened)) – \(previewEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.secondary.opacity(0.3), lineWidth: 1))
                    .padding(6)
                    .accessibilityHidden(true)
            }
            // Bottom resize handle embedded in the card so it moves with offset
            if isEditing {
                VStack { Spacer(); resizeHandleBottom }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: cardHeight, alignment: .top)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        // Keep layout constant in Edit for both growth and shrink (no push/pull of siblings)
        .padding(.bottom, editPaddingAdjustment)
        .opacity(status == .past ? 0.6 : 1)
        .padding(.vertical, isEditing ? 0 : TimelineStyle.cardVerticalPadView)
        .padding(.leading, currentGutter)
        .animation(
            .easeInOut(duration: TimelineStyle.gutterAnimationDuration),
            value: currentGutter
        )
        .animation(repositionAnimation, value: isEditing)
        // Move with visual offset in Edit and make the transform affect hit testing
        .offset(y: isEditing ? CGFloat(visualOffsetMinutes) * editMinuteHeight : 0)
        // Keep lifted above siblings while editing to avoid hit-test conflicts
        .zIndex(isEditing ? (isInteracting ? 200 : 100) : 0)
        // Whole-card move gesture (bottom handle has high priority and will override when grabbed)
        .gesture(moveDragGesture)
        .onAppear {
            currentGutter = keepGutterSpace ? totalGutter : 0
            displayedProgress = liveProgress
        }
        .onChange(of: liveProgress) { new in
            guard !isInteracting else { return }
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
        .accessibilityElement(children: AccessibilityChildBehavior.combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Edit-mode handles & gestures (UI only)

    private var handleSize: CGSize { .init(width: 42, height: 8) }

    private var resizeHandleBottom: some View {
        Capsule()
            .fill(.primary.opacity(0.15))
            .frame(width: handleSize.width, height: handleSize.height)
            .contentShape(Rectangle())
            .overlay(Capsule().stroke(.primary.opacity(0.25), lineWidth: 1))
            .padding(.bottom, 4)
            .highPriorityGesture(bottomResizeGesture)
            .accessibilityLabel("Resize end time")
    }

    private var moveDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragTranslationY) { value, state, _ in
                state = value.translation.height
            }
            .onChanged { value in
                guard isEditing else { return }
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    isInteracting = true
                    let snap = snapToMinutes(value.translation.height)
                    // Live preview uses base + snap (do not accumulate here)
                    proposedOffsetMinutes = baseOffsetMinutes + snap
                }
            }
            .onEnded { value in
                guard isEditing else { return }
                let snap = snapToMinutes(value.translation.height)
                // Commit: advance the base, then reflect in proposed
                baseOffsetMinutes += snap
                proposedOffsetMinutes = baseOffsetMinutes
                isInteracting = false
            }
    }

    private var bottomResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                guard isEditing else { return }
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) {
                    isInteracting = true
                    // Continuous live growth in points; clamp so duration never drops below min
                    let baseMins = durationMinutes + baseBottomDeltaMinutes
                    let liveMins = Double(value.translation.height / editMinuteHeight)
                    let minLiveMins = Double(minDurationMinutes - baseMins) // negative or zero
                    let clampedLiveMins = max(minLiveMins, liveMins)
                    liveResizePoints = CGFloat(clampedLiveMins) * editMinuteHeight
                }
            }
            .onEnded { value in
                guard isEditing else { return }
                let snap = snapToMinutes(value.translation.height)
                let minCombined = -(durationMinutes - minDurationMinutes)
                baseBottomDeltaMinutes = max(minCombined, baseBottomDeltaMinutes + snap)
                proposedBottomDeltaMinutes = baseBottomDeltaMinutes
                liveResizePoints = 0
                isInteracting = false
            }
    }

    private var repositionAnimation: Animation {
        .easeInOut(duration: TimelineStyle.cardRepositionDuration)
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

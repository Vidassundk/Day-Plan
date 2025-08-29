// TodayTimelineView.swift

import SwiftData
import SwiftUI

struct TodayTimelineView: View {
    let template: DayTemplate

    // Sorted today's plans
    private var plans: [ScheduledPlan] {
        (template.scheduledPlans ?? []).sorted { $0.startTime < $1.startTime }
    }

    private var dayStart: Date { template.startTime }
    private var dayEnd: Date { dayStart.addingTimeInterval(24 * 60 * 60) }

    // How often to refresh UI. Use 1 for smooth progress; bump to 30 to be battery-friendlier.
    private let tick: TimeInterval = 1

    var body: some View {
        TimelineView(.periodic(from: .now, by: tick)) { context in
            // Recompute "now" each tick, anchored to the template's day window
            let anchoredNow = TimeUtil.anchoredTime(context.date, to: dayStart)
            let now = min(max(anchoredNow, dayStart), dayEnd)

            VStack(alignment: .leading, spacing: 12) {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No plans scheduled today", systemImage: "clock")
                } else {
                    ForEach(plans) { sp in
                        TimelinePlanRow(sp: sp, dayStart: dayStart, now: now)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: now)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Row rendering with status + progress + correct countdown

private struct TimelinePlanRow: View {
    let sp: ScheduledPlan
    let dayStart: Date
    let now: Date

    private var start: Date { sp.startTime }
    private var end: Date { sp.startTime.addingTimeInterval(sp.duration) }

    private enum Status { case past, current, upcoming }

    private var status: Status {
        if now < start { return .upcoming }
        if now >= start && now < end { return .current }
        return .past
    }

    private var progress: Double {
        guard status == .current else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    // Build a *real* future Date for the timer by adding the delta to actual Date()
    private var countdownTarget: Date? {
        switch status {
        case .current:
            let remaining = end.timeIntervalSince(now)
            return remaining > 0 ? Date().addingTimeInterval(remaining) : nil
        case .upcoming:
            let untilStart = start.timeIntervalSince(now)
            return untilStart > 0 ? Date().addingTimeInterval(untilStart) : nil
        case .past:
            return nil
        }
    }

    var body: some View {
        let emoji = sp.plan?.emoji ?? "🧩"
        let title = sp.plan?.title ?? "Untitled"
        let desc = sp.plan?.planDescription
        let rangeText =
            "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) (\(TimeUtil.formatMinutes(Int(sp.duration / 60))))"

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(emoji).font(.title3)
                Text(title).font(.body)
                Spacer(minLength: 8)

                if status == .current {
                    Text("NOW")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                } else if status == .past {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let desc, !desc.isEmpty {
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }

            // Time range
            Text(rangeText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Correct countdown using a synthetic future date
            if let target = countdownTarget {
                HStack(spacing: 6) {
                    Image(
                        systemName: status == .current
                            ? "hourglass" : "clock.badge.exclamationmark")
                    Text(status == .current ? "Ends in" : "Starts in")
                    Text(target, style: .timer)
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if status == .current {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .animation(.linear(duration: 0.6), value: progress)
            }
        }
        .padding(10)
        .background(
            status == .current ? Color.accentColor.opacity(0.08) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(status == .past ? 0.55 : 1)
        .overlay(alignment: .leading) {
            if status == .current {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: 3)
            }
        }
    }
}

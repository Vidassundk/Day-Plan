import SwiftData
import SwiftUI

/// Minimal 4-step wizard that captures exactly your prompts.
/// Layout is intentionally simple; polish later without touching logic.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = OnboardingStateStore()
    @StateObject private var vm: OnboardingViewModel

    init() {
        let store = OnboardingStateStore()
        _store = StateObject(wrappedValue: store)
        _vm = StateObject(wrappedValue: OnboardingViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Group {
                    switch vm.step {
                    case 0: DailyRhythmStep(store: store)
                    case 1: WorkSchoolStep(store: store)
                    case 2: MovementStep(store: store)
                    default: FunAnchorStep(store: store)
                    }
                }
                .animation(.default, value: vm.step)

                HStack {
                    if vm.step > 0 {
                        Button("Back") { vm.back() }
                    }
                    Spacer()
                    if vm.step < 3 {
                        Button("Next") { vm.next() }.buttonStyle(
                            .borderedProminent)
                    } else {
                        Button("Create My Week") {
                            vm.finish()
                        }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Set up your week")
        }
        .onAppear { vm.attach(context: modelContext) }
    }
}

// MARK: - Steps

private struct DailyRhythmStep: View {
    @ObservedObject var store: OnboardingStateStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 1 — Daily Rhythm").font(.title3).bold()

            Text("When do you usually start your day?")
            choiceRow(
                values: DailyStartBand.allCases, current: store.startBandRaw
            ) { (band: DailyStartBand) in
                store.startBandRaw = band.rawValue
            }

            Divider().padding(.vertical, 4)

            Text("When do you usually wind down?")
            choiceRow(values: DailyEndBand.allCases, current: store.endBandRaw)
            { (band: DailyEndBand) in
                store.endBandRaw = band.rawValue
            }
        }
    }
}

private struct WorkSchoolStep: View {
    @ObservedObject var store: OnboardingStateStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 2 — Work / School").font(.title3).bold()
            choiceRow(
                values: WorkSchedule.allCases, current: store.workScheduleRaw
            ) { (schedule: WorkSchedule) in
                store.workScheduleRaw = schedule.rawValue
            }
            Text("You can always edit details later.").foregroundStyle(
                .secondary)
        }
    }
}

private struct MovementStep: View {
    @ObservedObject var store: OnboardingStateStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 3 — Movement").font(.title3).bold()
            choiceRow(
                values: MovementHabit.allCases, current: store.movementRaw
            ) { (habit: MovementHabit) in
                store.movementRaw = habit.rawValue
            }
        }
    }
}

private struct FunAnchorStep: View {
    @ObservedObject var store: OnboardingStateStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 4 — One Fun Anchor").font(.title3).bold()
            choiceRow(values: FunAnchor.allCases, current: store.funAnchorRaw) {
                (anchor: FunAnchor) in
                store.funAnchorRaw = anchor.rawValue
            }
            Text("We’ll place 1–2 blocks so your week feels alive.")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - UI helpers

private func choiceRow<
    T: CaseIterable & RawRepresentable & Hashable & CustomStringConvertible
>(
    values: T.AllCases,
    current: String,
    set: @escaping (T) -> Void
) -> some View where T.RawValue == String {
    // A quick, tappable row of options.
    // This is deliberately simple; replace with your favorite pill buttons later.
    HStack {
        ForEach(Array(values), id: \.self) { v in
            Button(v.rawValue) { set(v) }
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(
                    current == v.rawValue
                        ? Color.accentColor.opacity(0.2) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

extension DailyStartBand: CustomStringConvertible {
    var description: String { rawValue }
}
extension DailyEndBand: CustomStringConvertible {
    var description: String { rawValue }
}
extension WorkSchedule: CustomStringConvertible {
    var description: String { rawValue }
}
extension MovementHabit: CustomStringConvertible {
    var description: String { rawValue }
}
extension FunAnchor: CustomStringConvertible {
    var description: String { rawValue }
}

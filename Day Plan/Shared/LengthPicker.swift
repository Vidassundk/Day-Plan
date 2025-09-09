import SwiftUI

/// A compact, accessible duration picker that writes minutes to a binding.
/// - Uses a Date-based proxy for native wheel/keyboard UX.
/// - Clamps live to `maxMinutes` and snaps the wheel back if overflowed.
/// - Keeps the previous "minimum 5 minutes" heuristic, but if `maxMinutes` is
///   smaller than 5 we allow shorter values so the last minutes of the day are still selectable.
public struct LengthPicker: View {
    private let label: LocalizedStringKey
    @Binding private var minutes: Int
    @State private var proxy: Date

    private let maxMinutes: Int?  // nil = unbounded (original behavior)
    private let initialMinutes: Int

    public init(
        _ label: LocalizedStringKey = "Length",
        minutes: Binding<Int>,
        initialMinutes: Int = 30,
        maxMinutes: Int? = nil
    ) {
        self.label = label
        self._minutes = minutes
        self.initialMinutes = max(0, initialMinutes)
        self.maxMinutes = maxMinutes

        let base = Calendar.current.startOfDay(for: Date())
        let seed = Self.clamp(initialMinutes, toMax: maxMinutes)
        _proxy = State(
            initialValue: Calendar.current.date(
                byAdding: .minute, value: seed, to: base) ?? base)
    }

    public var body: some View {
        DatePicker(
            label, selection: $proxy, displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.compact)
        .onAppear {
            // Seed external binding on first show, clamped if needed.
            let c = Self.clamp(initialMinutes, toMax: maxMinutes)
            if minutes != c { minutes = c }
        }
        .onChange(of: proxy) { newValue in
            let comps = Calendar.current.dateComponents(
                [.hour, .minute], from: newValue)
            let raw = max(0, (comps.hour ?? 0) * 60 + (comps.minute ?? 0))
            let clamped = Self.clamp(raw, toMax: maxMinutes)
            if minutes != clamped { minutes = clamped }
            // If we had to clamp, push the wheel back so the UI matches.
            if clamped != raw {
                setProxy(minutes: clamped)
            }
        }
        .onChange(of: minutes) { newValue in
            // Keep wheel in sync if the bound value changes externally (e.g., start changed).
            let clamped = Self.clamp(newValue, toMax: maxMinutes)
            if clamped != newValue { minutes = clamped }
            syncProxyIfNeeded(to: clamped)
        }
        .onChange(of: maxMinutes) { _ in
            // If the ceiling moved (start time changed), re-clamp and sync UI.
            let clamped = Self.clamp(minutes, toMax: maxMinutes)
            if clamped != minutes { minutes = clamped }
            syncProxyIfNeeded(to: clamped)
        }
    }

    private func syncProxyIfNeeded(to mins: Int) {
        let comps = Calendar.current.dateComponents(
            [.hour, .minute], from: proxy)
        let current = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if current != mins { setProxy(minutes: mins) }
    }

    private func setProxy(minutes: Int) {
        let base = Calendar.current.startOfDay(for: Date())
        proxy =
            Calendar.current.date(byAdding: .minute, value: minutes, to: base)
            ?? base
    }

    private static func clamp(_ value: Int, toMax maxMinutes: Int?) -> Int {
        let maxM = max(0, maxMinutes ?? Int.max)
        // Preserve "min 5" unless the ceiling is below 5; then allow smaller values.
        let minM = maxM < 5 ? 0 : 5
        return min(max(value, minM), maxM)
    }
}

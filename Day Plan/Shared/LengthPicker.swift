import SwiftUI

/// A compact, accessible duration picker that writes minutes to a binding.
/// - Uses a `DatePicker` internally for native time wheel/keyboard UX.
/// - Clamps to a minimum of 5 minutes to avoid zero/negative values.
/// - `initialMinutes` only affects the initial wheel position.
public struct LengthPicker: View {
    @Binding private var minutes: Int
    @State private var proxy: Date
    private let label: LocalizedStringKey

    public init(
        _ label: LocalizedStringKey = "Length",
        minutes: Binding<Int>,
        initialMinutes: Int = 30
    ) {
        self.label = label
        self._minutes = minutes
        let base = Calendar.current.startOfDay(for: Date())
        let initial = max(5, initialMinutes)
        _proxy = State(
            initialValue: Calendar.current.date(
                byAdding: .minute, value: initial, to: base) ?? base
        )
    }

    public var body: some View {
        DatePicker(
            label, selection: $proxy, displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.compact)
        .onChange(of: proxy) { newValue in
            let comps = Calendar.current.dateComponents(
                [.hour, .minute], from: newValue)
            minutes = max(5, (comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        }
    }
}

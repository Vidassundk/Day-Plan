// EmojiKitPickerView.swift
import EmojiKit
import SwiftUI

@MainActor
struct EmojiKitPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    @State private var query = ""
    @State private var gridSelection = Emoji.GridSelection()

    private let allEmojis: [Emoji] = EmojiVersion.allCases.flatMap { $0.emojis }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                EmojiGridScrollView(
                    axis: .vertical,
                    emojis: allEmojis,
                    query: query.isEmpty ? nil : query,
                    selection: $gridSelection,
                    geometryProxy: geo,
                    action: { emoji in
                        selection = emoji.char
                        dismiss()
                    },
                    categoryEmojis: nil,
                    sectionTitle: { _ in EmptyView() },
                    gridItem: { p in
                        Text(p.emoji.char)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                )
            }
            // Pinned search
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search emoji"
            )

            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.35), .medium])
    }
}

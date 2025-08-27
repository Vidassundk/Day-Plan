//
//  PlanRowView.swift
//  Day Plan
//
//  Created by Vidas Sun on 27/08/2025.
//

import SwiftUI

struct PlanRowView: View {
    let emoji: String
    let title: String
    let description: String?
    let start: Date
    let durationSeconds: TimeInterval

    var body: some View {
        let end = start.addingTimeInterval(durationSeconds)
        HStack(spacing: 12) {
            Text(emoji.isEmpty ? "🧩" : emoji)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? "Untitled" : title).font(.body)

                if let desc = description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                }

                Text(
                    "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) (\(TimeUtil.formatMinutes(Int(durationSeconds/60))))"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

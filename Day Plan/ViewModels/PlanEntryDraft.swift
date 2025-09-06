// PlanEntryDraft.swift
import Foundation
import SwiftData

extension ModelContext {
    func plan(with id: UUID) -> Plan? {
        let fd = FetchDescriptor<Plan>(predicate: #Predicate { $0.id == id })
        return try? fetch(fd).first
    }
}

struct PlanEntryDraft: Identifiable, Equatable {
    let id = UUID()

    // Stable identity + display snapshots
    let planID: UUID
    let titleSnapshot: String
    let emojiSnapshot: String

    var start: Date
    var lengthMinutes: Int

    init(existingPlan: Plan, start: Date, lengthMinutes: Int) {
        self.planID = existingPlan.id
        self.titleSnapshot = existingPlan.title
        self.emojiSnapshot = existingPlan.emoji
        self.start = start
        self.lengthMinutes = lengthMinutes
    }
}

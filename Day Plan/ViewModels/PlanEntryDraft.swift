//
//  PlanEntryDraft.swift
//  Day Plan
//
//  Created by Vidas Sun on 27/08/2025.
//

import Foundation

struct PlanEntryDraft: Identifiable {
    var id = UUID()
    var existingPlan: Plan
    var start: Date
    var lengthMinutes: Int
}

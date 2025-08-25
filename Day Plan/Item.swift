//
//  Item.swift
//  Day Plan
//
//  Created by Vidas Sun on 25/08/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

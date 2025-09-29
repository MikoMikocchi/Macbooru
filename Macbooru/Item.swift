//
//  Item.swift
//  Macbooru
//
//  Created by Михаил Мацкевич on 29.09.2025.
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

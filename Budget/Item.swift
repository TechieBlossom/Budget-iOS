//
//  Item.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
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

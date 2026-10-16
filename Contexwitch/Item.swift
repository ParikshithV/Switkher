//
//  Item.swift
//  Contexwitch
//
//  Created by Parikshith V on 16/10/26.
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

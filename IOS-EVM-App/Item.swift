//
//  Item.swift
//  IOS-EVM-App
//
//  Created by Meet  on 27/08/25.
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

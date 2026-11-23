//
//  FakeMonitor.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// One monitor's DDC side: which input it shows and how it misbehaves.
@MainActor
final class FakeMonitor {
    let id: MonitorID
    var input: Int
    var refusesSwitch = false
    var ignoredWrites = 0
    // takes this many writes, then refuses the rest
    var refusesAfter: Int?
    var answersReads = true
    var writes = [Int]()

    init(id: MonitorID, input: Int) {
        self.id = id
        self.input = input
    }
}

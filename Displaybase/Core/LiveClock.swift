//
//  LiveClock.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

@MainActor
final class LiveClock: DeskClock {
    var now: ContinuousClock.Instant { .now }

    func sleep(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}

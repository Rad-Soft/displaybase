//
//  FakeClock.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// Sleeping returns at once, but other tasks get a turn and time still moves forward.
@MainActor
final class FakeClock: DeskClock {
    private let start = ContinuousClock.now
    private(set) var elapsed = Duration.zero
    private(set) var sleeps = [Duration]()

    var now: ContinuousClock.Instant { start + elapsed }

    func sleep(for duration: Duration) async {
        sleeps.append(duration)
        elapsed += duration
        await Task.yield()
    }
}

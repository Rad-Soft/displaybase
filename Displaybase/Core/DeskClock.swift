//
//  DeskClock.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// Time for the controller, so waiting can be skipped when nothing real is on the other end.
@MainActor
protocol DeskClock: AnyObject {
    var now: ContinuousClock.Instant { get }
    func sleep(for duration: Duration) async
}

//
//  FakeWindows.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

@MainActor
final class FakeWindows: DeskWindows {
    private let log: EventLog
    private let label: String
    var isTrusted = true
    private(set) var accessRequests = 0

    init(label: String, log: EventLog) {
        self.label = label
        self.log = log
    }

    func requestAccess() {
        accessRequests += 1
    }

    func capture() {
        log.add("\(label) capture")
    }

    func restoreAll() {
        log.add("\(label) restore all")
    }

    func restore(on monitor: MonitorID) {
        log.add("\(label) restore \(monitor.name)")
    }

    func forget() {
        log.add("\(label) forget")
    }
}

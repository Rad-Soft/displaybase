//
//  FakeMonitors.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

@MainActor
final class FakeMonitors: DeskMonitors {
    private let log: EventLog
    private(set) var all = [FakeMonitor]()

    init(log: EventLog) {
        self.log = log
    }

    func add(_ monitor: FakeMonitor) {
        all.append(monitor)
    }

    func monitors() async -> [MonitorID] {
        all.map(\.id)
    }

    func readInput(of monitor: MonitorID) async -> Int? {
        guard let fake = all.first(where: { $0.id == monitor }), fake.answersReads else { return nil }
        return fake.input
    }

    func writeInput(_ value: Int, on monitor: MonitorID) async -> Bool {
        guard let fake = all.first(where: { $0.id == monitor }) else { return false }
        log.add("ddc \(monitor.name) 0x\(String(value, radix: 16))")
        fake.writes.append(value)
        if fake.ignoredWrites > 0 {
            fake.ignoredWrites -= 1
            return true
        }
        if let limit = fake.refusesAfter, fake.writes.count > limit { return true }
        if !fake.refusesSwitch { fake.input = value }
        return true
    }
}

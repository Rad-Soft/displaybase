//
//  LiveMonitors.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

@MainActor
final class LiveMonitors: DeskMonitors {
    func monitors() async -> [MonitorID] {
        await Task.detached(operation: { DDC.monitors() }).value
    }

    func readInput(of monitor: MonitorID) async -> Int? {
        await Task.detached(operation: { DDC.read(VCP.input, on: monitor) }).value
    }

    func writeInput(_ value: Int, on monitor: MonitorID) async -> Bool {
        await Task.detached(operation: { DDC.write(VCP.input, value: value, on: monitor) }).value
    }
}

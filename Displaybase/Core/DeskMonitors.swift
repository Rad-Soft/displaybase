//
//  DeskMonitors.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// Reads and switches monitor inputs over DDC.
@MainActor
protocol DeskMonitors: AnyObject {
    func monitors() async -> [MonitorID]
    func readInput(of monitor: MonitorID) async -> Int?
    func writeInput(_ value: Int, on monitor: MonitorID) async -> Bool
}

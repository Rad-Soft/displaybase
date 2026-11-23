//
//  DeskWindows.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics

/// Remembers where windows were and puts them back.
@MainActor
protocol DeskWindows: AnyObject {
    var isTrusted: Bool { get }
    func requestAccess()
    func capture()
    func restoreAll()
    func restore(on monitor: MonitorID)
    func forget()
}

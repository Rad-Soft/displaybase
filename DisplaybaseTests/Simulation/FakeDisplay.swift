//
//  FakeDisplay.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation

/// One screen as macOS sees it.
@MainActor
final class FakeDisplay {
    let id: CGDirectDisplayID
    let monitor: MonitorID
    let isBuiltin: Bool
    var frame: CGRect
    var rotation = 0
    var active = true
    var refusesDisable = false
    var resetsRotation = false
    var cannotRotate = false
    // reports inactive for this many checks after being turned on
    var slowChecks = 0
    var pendingChecks = 0

    init(id: CGDirectDisplayID, monitor: MonitorID, isBuiltin: Bool, frame: CGRect) {
        self.id = id
        self.monitor = monitor
        self.isBuiltin = isBuiltin
        self.frame = frame
    }
}

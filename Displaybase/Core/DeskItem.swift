//
//  DeskItem.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics

/// One screen on the desk map.
struct DeskItem: Identifiable, Equatable {
    let monitor: MonitorID
    let frame: CGRect
    let isBuiltin: Bool
    let onPC: Bool

    var id: MonitorID { monitor }
}

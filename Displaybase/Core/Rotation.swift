//
//  Rotation.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import CoreGraphics
import Foundation

/// Reads and sets screen rotation. There's no public API to set it, so this goes through MonitorPanel,
/// the private framework System Settings uses for the Displays pane.
@MainActor
enum Rotation {
    private static let loaded = dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel", RTLD_NOW) != nil

    static func current(_ id: CGDirectDisplayID) -> Int {
        Int(CGDisplayRotation(id)) % 360
    }

    @discardableResult
    static func set(_ degrees: Int, on id: CGDirectDisplayID) -> Bool {
        guard loaded, let display = panelDisplay(id),
              display.responds(to: NSSelectorFromString("setOrientation:")),
              (display.value(forKey: "canChangeOrientation") as? Bool) == true else { return false }
        display.setValue(degrees, forKey: "orientation")
        return true
    }

    // a fresh manager each time, it caches the display list from when it was made
    private static func panelDisplay(_ id: CGDirectDisplayID) -> NSObject? {
        guard let managerType = NSClassFromString("MPDisplayMgr") as? NSObject.Type else { return nil }
        let manager = managerType.init()
        guard manager.responds(to: NSSelectorFromString("displays")),
              let displays = manager.value(forKey: "displays") as? [NSObject] else { return nil }
        return displays.first {
            $0.responds(to: NSSelectorFromString("displayID")) && ($0.value(forKey: "displayID") as? Int) == Int(id)
        }
    }
}

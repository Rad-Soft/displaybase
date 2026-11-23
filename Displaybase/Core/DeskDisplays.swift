//
//  DeskDisplays.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics

/// What macOS knows about the connected screens, and the ways to change it.
@MainActor
protocol DeskDisplays: AnyObject {
    func online() -> [CGDirectDisplayID]
    func screens() -> [ScreenInfo]
    func display(matching monitor: MonitorID) -> CGDirectDisplayID?
    func isActive(_ id: CGDirectDisplayID) -> Bool
    func isMain(_ id: CGDirectDisplayID) -> Bool
    func bounds(of id: CGDirectDisplayID) -> CGRect
    func snapshot() -> LayoutSnapshot
    func restore(_ snapshot: LayoutSnapshot)
    func makeMain(_ id: CGDirectDisplayID)
    @discardableResult
    func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) -> Bool
    func rotation(of id: CGDirectDisplayID) -> Int
    @discardableResult
    func setRotation(_ degrees: Int, on id: CGDirectDisplayID) -> Bool
    /// Called after screens are added, removed or rearranged, with whether one was added.
    func onReconfigure(_ handler: @escaping @MainActor (Bool) -> Void)
}

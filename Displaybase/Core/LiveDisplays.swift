//
//  LiveDisplays.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics

@MainActor
final class LiveDisplays: DeskDisplays {
    private var handler: (@MainActor (Bool) -> Void)?
    private var registered = false

    func online() -> [CGDirectDisplayID] { DisplayLayout.online() }
    func screens() -> [ScreenInfo] { DisplayLayout.screens() }
    func display(matching monitor: MonitorID) -> CGDirectDisplayID? { DisplayLayout.display(matching: monitor) }
    func isActive(_ id: CGDirectDisplayID) -> Bool { DisplayLayout.isActive(id) }
    func isMain(_ id: CGDirectDisplayID) -> Bool { CGDisplayIsMain(id) != 0 }
    func bounds(of id: CGDirectDisplayID) -> CGRect { CGDisplayBounds(id) }
    func snapshot() -> LayoutSnapshot { DisplayLayout.snapshot() }
    func restore(_ snapshot: LayoutSnapshot) { DisplayLayout.restore(snapshot) }
    func makeMain(_ id: CGDirectDisplayID) { DisplayLayout.makeMain(id) }
    func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) -> Bool { DisplayLayout.setEnabled(id, enabled) }
    func rotation(of id: CGDirectDisplayID) -> Int { Rotation.current(id) }
    func setRotation(_ degrees: Int, on id: CGDirectDisplayID) -> Bool { Rotation.set(degrees, on: id) }

    func onReconfigure(_ handler: @escaping @MainActor (Bool) -> Void) {
        self.handler = handler
        guard !registered else { return }
        registered = true
        CGDisplayRegisterReconfigurationCallback({ _, flags, userInfo in
            guard !flags.contains(.beginConfigurationFlag), let userInfo else { return }
            let displays = Unmanaged<LiveDisplays>.fromOpaque(userInfo).takeUnretainedValue()
            let added = flags.contains(.addFlag)
            Task { @MainActor in displays.handler?(added) }
        }, Unmanaged.passUnretained(self).toOpaque())
    }
}

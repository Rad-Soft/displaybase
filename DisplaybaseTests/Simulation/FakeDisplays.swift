//
//  FakeDisplays.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation

@MainActor
final class FakeDisplays: DeskDisplays {
    private let log: EventLog
    private(set) var all = [FakeDisplay]()
    private(set) var lostEveryScreen = false
    private(set) var handler: (@MainActor (Bool) -> Void)?

    init(log: EventLog) {
        self.log = log
    }

    func add(_ display: FakeDisplay) {
        all.append(display)
    }

    /// The display at the origin, which owns the menu bar.
    var main: FakeDisplay? {
        all.first { $0.active && $0.frame.origin == .zero }
    }

    func fireReconfigure(added: Bool) {
        handler?(added)
    }

    /// Closing the lid turns the built-in screen off without anyone asking.
    func closeLid() {
        all.first { $0.isBuiltin }?.active = false
    }

    func openLid() {
        all.first { $0.isBuiltin }?.active = true
    }

    func online() -> [CGDirectDisplayID] {
        all.filter(\.active).map(\.id)
    }

    func screens() -> [ScreenInfo] {
        all.filter(\.active).map { ScreenInfo(id: $0.id, monitor: $0.monitor, isBuiltin: $0.isBuiltin) }
    }

    func display(matching monitor: MonitorID) -> CGDirectDisplayID? {
        all.first { $0.active && $0.monitor == monitor }?.id
    }

    func isActive(_ id: CGDirectDisplayID) -> Bool {
        guard let display = find(id) else { return false }
        if display.pendingChecks > 0 {
            display.pendingChecks -= 1
            return false
        }
        return display.active
    }

    func isMain(_ id: CGDirectDisplayID) -> Bool {
        find(id)?.frame.origin == .zero
    }

    func bounds(of id: CGDirectDisplayID) -> CGRect {
        find(id)?.frame ?? .zero
    }

    func snapshot() -> LayoutSnapshot {
        log.add("snapshot")
        return LayoutSnapshot(placements: all.filter(\.active).map {
            .init(
                monitor: $0.monitor,
                x: Int32($0.frame.minX),
                y: Int32($0.frame.minY),
                rotation: $0.rotation,
                width: Int32($0.frame.width),
                height: Int32($0.frame.height),
                isBuiltin: $0.isBuiltin
            )
        })
    }

    func restore(_ snapshot: LayoutSnapshot) {
        log.add("restore layout")
        for placement in snapshot.placements {
            guard let display = all.first(where: { $0.active && $0.monitor == placement.monitor }) else { continue }
            display.rotation = placement.rotation
            display.frame.origin = CGPoint(x: Int(placement.x), y: Int(placement.y))
        }
    }

    func makeMain(_ id: CGDirectDisplayID) {
        guard let target = find(id) else { return }
        log.add("main \(target.monitor.name)")
        let anchor = target.frame.origin
        for display in all where display.active {
            display.frame.origin = CGPoint(x: display.frame.origin.x - anchor.x, y: display.frame.origin.y - anchor.y)
        }
    }

    func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) -> Bool {
        guard let display = find(id) else { return false }
        if !enabled, display.refusesDisable {
            log.add("refused disable \(display.monitor.name)")
            return false
        }
        log.add("\(enabled ? "enable" : "disable") \(display.monitor.name)")
        display.active = enabled
        display.pendingChecks = enabled ? display.slowChecks : 0
        // a new set of screens comes up with whatever layout macOS saved for it
        for other in all where other.resetsRotation { other.rotation = 0 }
        if online().isEmpty { lostEveryScreen = true }
        return true
    }

    func rotation(of id: CGDirectDisplayID) -> Int {
        find(id)?.rotation ?? 0
    }

    func setRotation(_ degrees: Int, on id: CGDirectDisplayID) -> Bool {
        guard let display = find(id), !display.cannotRotate else { return false }
        log.add("rotate \(display.monitor.name) \(degrees)")
        display.rotation = degrees
        return true
    }

    func onReconfigure(_ handler: @escaping @MainActor (Bool) -> Void) {
        self.handler = handler
    }

    private func find(_ id: CGDirectDisplayID) -> FakeDisplay? {
        all.first { $0.id == id }
    }
}

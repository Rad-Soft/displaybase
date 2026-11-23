//
//  DisplayLayout.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import AppKit
import CoreGraphics

@_silgen_name("CGSConfigureDisplayEnabled")
private func CGSConfigureDisplayEnabled(_ config: CGDisplayConfigRef?, _ display: CGDirectDisplayID, _ enabled: Bool) -> CGError

struct LayoutSnapshot: Codable, Sendable {
    struct Placement: Codable, Sendable {
        let monitor: MonitorID
        let x: Int32
        let y: Int32
        let rotation: Int
        let width: Int32
        let height: Int32
        let isBuiltin: Bool
    }

    let placements: [Placement]
}

struct ScreenInfo: Identifiable, Hashable, Sendable {
    let id: CGDirectDisplayID
    let monitor: MonitorID
    let isBuiltin: Bool
}

@MainActor
enum DisplayLayout {
    static func online() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count))).filter { CGDisplayIsActive($0) != 0 }
    }

    static func screens() -> [ScreenInfo] {
        online().map { ScreenInfo(id: $0, monitor: monitor(for: $0), isBuiltin: CGDisplayIsBuiltin($0) != 0) }
    }

    static func display(matching monitor: MonitorID) -> CGDirectDisplayID? {
        online().first { self.monitor(for: $0) == monitor }
    }

    static func isActive(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayIsActive(id) != 0
    }

    static func monitor(for id: CGDirectDisplayID) -> MonitorID {
        MonitorID(
            vendor: CGDisplayVendorNumber(id),
            model: CGDisplayModelNumber(id),
            serial: CGDisplaySerialNumber(id),
            name: name(for: id)
        )
    }

    static func snapshot() -> LayoutSnapshot {
        LayoutSnapshot(placements: online().map {
            let bounds = CGDisplayBounds($0)
            return .init(
                monitor: monitor(for: $0),
                x: Int32(bounds.minX),
                y: Int32(bounds.minY),
                rotation: Rotation.current($0),
                width: Int32(bounds.width),
                height: Int32(bounds.height),
                isBuiltin: CGDisplayIsBuiltin($0) != 0
            )
        })
    }

    /// Rotation first, since it changes a screen's size and the origins depend on that.
    @discardableResult
    static func restore(_ snapshot: LayoutSnapshot) -> Bool {
        let allBack = snapshot.placements.allSatisfy { display(matching: $0.monitor) != nil }
        for placement in snapshot.placements {
            guard let id = display(matching: placement.monitor), Rotation.current(id) != placement.rotation else { continue }
            Rotation.set(placement.rotation, on: id)
        }
        // saved for good once every screen is back, so macOS keeps the user's own layout for this set
        return configure(allBack ? .permanently : .forSession) { config in
            for placement in snapshot.placements {
                guard let id = display(matching: placement.monitor) else { continue }
                CGConfigureDisplayOrigin(config, id, placement.x, placement.y)
            }
            return true
        }
    }

    /// The display at the origin owns the menu bar and the Dock.
    @discardableResult
    static func makeMain(_ target: CGDirectDisplayID) -> Bool {
        let anchor = CGDisplayBounds(target).origin
        return configure(.forSession) { config in
            for id in online() {
                let origin = CGDisplayBounds(id).origin
                CGConfigureDisplayOrigin(config, id, Int32(origin.x - anchor.x), Int32(origin.y - anchor.y))
            }
            return true
        }
    }

    @discardableResult
    static func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) -> Bool {
        // session only, so a logout always brings a turned-off screen back
        configure(.forSession) { CGSConfigureDisplayEnabled($0, id, enabled) == .success }
    }

    private static func configure(_ option: CGConfigureOption, _ body: (CGDisplayConfigRef?) -> Bool) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        guard body(config) else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGCompleteDisplayConfiguration(config, option) == .success
    }

    private static func name(for id: CGDirectDisplayID) -> String {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }
        return screen?.localizedName ?? (CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)")
    }
}

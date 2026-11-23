//
//  WindowKeeper.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import AppKit
import ApplicationServices

/// Remembers where every window was so they can go back after macOS shuffles them around.
/// Needs Accessibility access; without it, this quietly does nothing.
@MainActor
final class WindowKeeper: DeskWindows {
    private struct Saved {
        let window: AXUIElement
        let frame: CGRect
        let screen: MonitorID?
        let screenOrigin: CGPoint
    }

    private var saved: [Saved] = []

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    var isTrusted: Bool { Self.isTrusted }

    func requestAccess() {
        Self.requestAccess()
    }

    func capture() {
        saved.removeAll()
        guard Self.isTrusted else { return }
        let screens = DisplayLayout.online().map { (id: $0, bounds: CGDisplayBounds($0)) }
        // a hung app shouldn't stall the switch
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.3)

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = value(element, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for window in windows {
                guard value(window, kAXMinimizedAttribute) as? Bool != true,
                      value(window, "AXFullScreen") as? Bool != true,
                      let frame = frame(of: window) else { continue }
                let screen = screens.first { $0.bounds.contains(CGPoint(x: frame.midX, y: frame.midY)) }
                saved.append(Saved(
                    window: window,
                    frame: frame,
                    screen: screen.map { DisplayLayout.monitor(for: $0.id) },
                    screenOrigin: screen?.bounds.origin ?? .zero
                ))
            }
        }
    }

    /// Everything back where it was. Only call once the screens are laid out like they were at capture.
    func restoreAll() {
        for item in saved {
            move(item.window, to: item.frame)
        }
    }

    /// Just the windows that were on this screen, shifted to wherever the screen sits now.
    func restore(on monitor: MonitorID) {
        guard let id = DisplayLayout.display(matching: monitor) else { return }
        let origin = CGDisplayBounds(id).origin
        for item in saved where item.screen == monitor {
            move(item.window, to: item.frame.offsetBy(dx: origin.x - item.screenOrigin.x, dy: origin.y - item.screenOrigin.y))
        }
    }

    func forget() {
        saved.removeAll()
    }

    private func move(_ window: AXUIElement, to frame: CGRect) {
        // skip anything that would land off screen, like a window from a screen that isn't back
        guard DisplayLayout.online().contains(where: { CGDisplayBounds($0).contains(CGPoint(x: frame.midX, y: frame.midY)) }) else { return }
        var origin = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin), let dimensions = AXValueCreate(.cgSize, &size) else { return }
        // position again after resizing, since apps clamp size to the screen the window is on
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = axValue(window, kAXPositionAttribute), let size = axValue(window, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &origin),
              AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: origin, size: dimensions)
    }

    // apps answer for themselves here, so check it's really the type it should be
    private func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let value = value(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXValue.self)
    }

    private func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success ? result : nil
    }
}

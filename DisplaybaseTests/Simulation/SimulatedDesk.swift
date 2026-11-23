//
//  SimulatedDesk.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation

/// A whole desk made of fakes, wired to a real controller and real preferences kept in a throwaway suite.
@MainActor
final class SimulatedDesk {
    typealias Notification = (title: String, body: String)

    let suite: String
    let defaults: UserDefaults
    private(set) var prefs: Preferences
    let log = EventLog()
    let monitors: FakeMonitors
    let displays: FakeDisplays
    let windows: FakeWindows
    let lentWindows: FakeWindows
    let remote = FakeRemote()
    let usb = FakeSwitchDevice()
    let hotkey = FakeHotkey()
    let clock = FakeClock()
    private(set) var notifications = [Notification]()
    private(set) lazy var controller = makeController(prefs)
    private var nextID: CGDirectDisplayID = 1
    private var nextX: CGFloat = 0

    init() {
        suite = "displaybase.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        prefs = Preferences(defaults: defaults)
        monitors = FakeMonitors(log: log)
        displays = FakeDisplays(log: log)
        windows = FakeWindows(label: "windows", log: log)
        lentWindows = FakeWindows(label: "lent windows", log: log)
    }

    /// For tests that bring their own preferences.
    convenience init(prefs: Preferences) {
        self.init()
        self.prefs = prefs
    }

    deinit {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    private func makeController(_ prefs: Preferences) -> DeskController {
        DeskController(
            prefs: prefs,
            monitors: monitors,
            displays: displays,
            usb: usb,
            windows: windows,
            lentWindows: lentWindows,
            remote: remote,
            hotkey: hotkey,
            clock: clock,
            notify: { [weak self] title, body in
                self?.notifications.append((title, body))
                self?.log.add("notify \(title)")
            }
        )
    }

    /// A new launch of the app: same preferences on disk, same hardware.
    @discardableResult
    func relaunch() -> DeskController {
        prefs = Preferences(defaults: defaults)
        controller = makeController(prefs)
        return controller
    }

    /// An external monitor with its screen. Screens line up left to right unless placed.
    @discardableResult
    func add(
        _ name: String,
        role: ScreenRole = .stays,
        input: Int = 0x0F,
        pcInput: Int = 0x11,
        pinnedRotation: Int? = nil,
        rotated: Int = 0,
        size: CGSize = CGSize(width: 2560, height: 1440),
        x: CGFloat? = nil
    ) -> FakeMonitor {
        let id = MonitorID(vendor: 1, model: nextID, serial: 1, name: name)
        let frame = CGRect(origin: CGPoint(x: x ?? nextX, y: 0), size: size)
        nextX = frame.maxX
        let display = FakeDisplay(id: nextID, monitor: id, isBuiltin: false, frame: frame)
        display.rotation = rotated
        nextID += 1
        displays.add(display)
        let monitor = FakeMonitor(id: id, input: input)
        monitors.add(monitor)
        prefs.screens.append(DeskScreen(monitor: id, role: role, pcInput: pcInput, macInput: nil, rotation: pinnedRotation))
        return monitor
    }

    /// An external monitor macOS knows about that hasn't been added in settings yet.
    @discardableResult
    func addUnconfigured(_ name: String, input: Int? = 0x0F, size: CGSize = CGSize(width: 2560, height: 1440), rotated: Int = 0) -> FakeMonitor {
        let before = prefs.screens
        let monitor = add(name, input: input ?? 0x0F, rotated: rotated, size: size)
        prefs.screens = before
        monitor.answersReads = input != nil
        return monitor
    }

    /// The laptop's own screen, which has no DDC and no entry in settings.
    @discardableResult
    func addLaptop(x: CGFloat? = nil) -> FakeDisplay {
        let id = MonitorID(vendor: 0x610, model: nextID, serial: 0, name: "Built-in Display")
        let size = CGSize(width: 1512, height: 982)
        let frame = CGRect(origin: CGPoint(x: x ?? nextX, y: 0), size: size)
        nextX = frame.maxX
        let display = FakeDisplay(id: nextID, monitor: id, isBuiltin: true, frame: frame)
        nextID += 1
        displays.add(display)
        return display
    }

    func monitor(_ name: String) -> FakeMonitor {
        monitors.all.first { $0.id.name == name }!
    }

    func display(_ name: String) -> FakeDisplay {
        displays.all.first { $0.monitor.name == name }!
    }

    func id(_ name: String) -> MonitorID {
        monitor(name).id
    }

    func screen(_ name: String) -> DeskScreen? {
        prefs.screen(id(name))
    }

    /// Settings for following a keyboard switch.
    func useSwitch(askRemote: Bool = false, takesBack: Bool = false) {
        prefs.switchDevice = USBDeviceID(vendor: 0x046D, product: 0xC31C, name: "Keyboard")
        prefs.followSwitch = true
        prefs.switchBackTakesBack = takesBack
        if askRemote { prefs.remoteHost = "gaming" }
        // start() does this too, but it also begins polling
        usb.onChange = { [weak self] present in self?.controller.switchMoved(toMac: present) }
    }
}

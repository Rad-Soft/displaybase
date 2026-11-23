//
//  DeskController.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import AppKit
import Observation
import OSLog

@MainActor
@Observable
final class DeskController {
    enum Mode: Sendable {
        case mac
        case pc
    }

    var mode = Mode.mac
    var busy = false
    var pcOnline: Bool?
    var switchSpot = SwitchSpot.unknown
    var note: String?
    var windowsAllowed: Bool
    var shortcutTaken = false
    var layout = LayoutSnapshot(placements: [])
    let prefs: Preferences

    @ObservationIgnored var showSetup: () -> Void = {}
    @ObservationIgnored let monitors: any DeskMonitors
    @ObservationIgnored let displays: any DeskDisplays
    @ObservationIgnored let usb: any DeskSwitchDevice
    @ObservationIgnored let windows: any DeskWindows
    @ObservationIgnored let lentWindows: any DeskWindows
    @ObservationIgnored let remote: any DeskRemote
    @ObservationIgnored let clock: any DeskClock
    @ObservationIgnored let notify: @MainActor (String, String) -> Void
    @ObservationIgnored let log = Logger(subsystem: "com.radsoft.displaybase", category: "desk")
    @ObservationIgnored var followTask: Task<Void, Never>?
    @ObservationIgnored var reconfigureTask: Task<Void, Never>?
    @ObservationIgnored var screenCameBack = false
    // screens that didn't switch back, and how many more times to try
    @ObservationIgnored var strays = [MonitorID: Int]()
    @ObservationIgnored private let hotkey: any DeskHotkey
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var offlinePolls = 0
    @ObservationIgnored private var missingPolls = 0
    @ObservationIgnored private var seenOnline = false
    @ObservationIgnored private var started = false

    var desk: [DeskItem] {
        let placements = prefs.handover?.layout?.placements ?? layout.placements
        return placements.map { placement in
            DeskItem(
                monitor: placement.monitor,
                frame: CGRect(
                    x: Int(placement.x),
                    y: Int(placement.y),
                    width: Int(placement.width),
                    height: Int(placement.height)
                ),
                isBuiltin: placement.isBuiltin,
                onPC: prefs.handover?.has(placement.monitor) ?? false
            )
        }
    }

    var everyScreenAway: Bool {
        prefs.handover?.away.contains(where: \.optional) ?? false
    }

    init(
        prefs: Preferences,
        monitors: any DeskMonitors = LiveMonitors(),
        displays: any DeskDisplays = LiveDisplays(),
        usb: any DeskSwitchDevice = USBWatcher(),
        windows: any DeskWindows = WindowKeeper(),
        lentWindows: any DeskWindows = WindowKeeper(),
        remote: any DeskRemote = LiveRemote(),
        hotkey: any DeskHotkey = Hotkey(),
        clock: any DeskClock = LiveClock(),
        notify: @escaping @MainActor (String, String) -> Void = { Notifier.post($0, $1) }
    ) {
        self.prefs = prefs
        self.monitors = monitors
        self.displays = displays
        self.usb = usb
        self.windows = windows
        self.lentWindows = lentWindows
        self.remote = remote
        self.hotkey = hotkey
        self.clock = clock
        self.notify = notify
        windowsAllowed = windows.isTrusted
        // relaunched mid-handover: the monitor is still over there, so pick up where it left off
        if prefs.handover != nil { mode = .pc }
    }

    func start() {
        started = true
        usb.onChange = { [weak self] present in self?.switchMoved(toMac: present) }
        watchSwitchDevice()
        hotkey.action = { [weak self] in self?.toggle() }
        shortcutChanged()
        displays.onReconfigure { [weak self] added in self?.displaysChanged(added: added) }
        layout = displays.snapshot()
        holdRotation()
        startPolling()
    }

    func shortcutChanged() {
        guard started else { return }
        shortcutTaken = !hotkey.register(prefs.shortcut)
    }

    // so recording over the current shortcut doesn't set it off
    func pauseShortcut() {
        hotkey.unregister()
    }

    func toggle() {
        Task {
            if mode == .mac {
                await handOver("shortcut")
            } else {
                await takeBack("shortcut")
            }
        }
    }

    func handle(_ url: URL) {
        guard prefs.allowLinks, url.scheme == "displaybase" else { return }
        switch url.host() {
        case "pc": Task { await handOver("link") }
        case "mac": Task { await takeBack("link") }
        case "toggle": toggle()
        default: break
        }
    }

    func allowWindowRestore() {
        windows.requestAccess()
    }

    /// Runs to the end even if whatever started it is canceled. Stopping half way leaves a screen on the wrong computer.
    func uninterrupted(_ work: @escaping @MainActor () async -> Void) async {
        await Task { await work() }.value
    }

    func whenIdle() async {
        let deadline = clock.now + .seconds(60)
        while busy, clock.now < deadline {
            await clock.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
        }
    }

    /// For quitting and updating, which can land in the middle of a hand-over.
    func comeHome(_ reason: String) async {
        await uninterrupted { [self] in
            await whenIdle()
            await takeBack(reason)
        }
    }

    // MARK: - Setup

    /// Adds monitors it hasn't seen. The first time, the biggest landscape one is the one to share.
    func findScreens() async {
        let found = await monitors.monitors()
        layout = displays.snapshot()
        let firstTime = prefs.screens.isEmpty
        for monitor in found where prefs.screen(monitor) == nil {
            let input = await monitors.readInput(of: monitor)
            let rotation = displays.display(matching: monitor).map { displays.rotation(of: $0) } ?? 0
            prefs.screens.append(DeskScreen(
                monitor: monitor,
                pcInput: input == 0x0F ? 0x11 : 0x0F,
                macInput: input,
                rotation: rotation == 0 ? nil : rotation
            ))
        }
        guard firstTime else { return }
        let sharable = prefs.screens.compactMap { screen in
            displays.display(matching: screen.monitor).map { (monitor: screen.monitor, id: $0) }
        }
        func rank(_ id: CGDirectDisplayID) -> Double {
            let bounds = displays.bounds(of: id)
            return bounds.width * bounds.height * (bounds.width >= bounds.height ? 2 : 1)
        }
        if let main = sharable.max(by: { rank($0.id) < rank($1.id) }) {
            prefs.update(main.monitor) { $0.role = .goes }
        }
    }

    /// Shows the other computer on one screen for a few seconds, then comes back by itself.
    func preview(_ screen: DeskScreen) async {
        guard mode == .mac, !busy else { return }
        busy = true
        defer { busy = false }
        guard let back = await currentInput(of: screen.monitor) else {
            note = "\(screen.monitor.name) doesn't answer. Turn on DDC/CI in the monitor's own menu."
            return
        }
        note = nil
        _ = await monitors.writeInput(screen.pcInput, on: screen.monitor)
        await clock.sleep(for: .seconds(5))
        if await setInput(back, on: screen.monitor, attempts: 6) {
            if back != screen.pcInput { prefs.update(screen.monitor) { $0.macInput = back } }
        } else {
            note = "\(screen.monitor.name) didn't come back. Use the input button on the monitor."
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await clock.sleep(for: await pollOnce())
            }
        }
    }

    /// One round of checking on the other computer. Returns how long to wait before the next.
    func pollOnce() async -> Duration {
        windowsAllowed = windows.isTrusted
        await fetchStrays()
        guard prefs.hasRemote else {
            pcOnline = nil
            return .seconds(15)
        }
        let online = await remote.isReachable(host: prefs.remoteHost)
        pcOnline = online

        if mode == .pc, !busy {
            seenOnline = seenOnline || online
            offlinePolls = online ? 0 : offlinePolls + 1
            // only bail once it was actually up, so a booting computer gets a chance
            if seenOnline && offlinePolls >= 3 {
                await takeBack("other computer went offline")
            } else if online, prefs.followSwitch, prefs.handover?.keyboardOnPC == true, !usb.isPresent,
                      let device = prefs.switchDevice,
                      let onPC = await remote.has(device, host: prefs.remoteHost, system: prefs.remoteSystem) {
                missingPolls = onPC ? 0 : missingPolls + 1
                // things can change while it was being asked
                if missingPolls >= 2, mode == .pc, !busy {
                    missingPolls = 0
                    prefs.handover?.keyboardOnPC = false
                    if prefs.switchBackTakesBack {
                        await takeBack("switch left the other computer")
                    }
                    followTask?.cancel()
                    followTask = Task { await warnIfSwitchLost(after: .seconds(8)) }
                }
            }
        } else if mode == .mac {
            offlinePolls = 0
            missingPolls = 0
            seenOnline = false
        }

        return mode == .pc ? .seconds(4) : .seconds(15)
    }
}

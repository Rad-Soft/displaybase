//
//  DeskController+Handover.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import AppKit

extension DeskController {
    func handOver(_ reason: String) async {
        guard mode == .mac, !busy, let plan = planHandover() else { return }
        busy = true
        defer { busy = false }
        log.notice("handing over: \(reason, privacy: .public)")
        note = nil

        let snapshot = displays.snapshot()
        windows.capture()
        strays = [:]
        await learnInputs()

        var gone = [Handover.Away]()
        for item in plan.leaving {
            if await setInput(item.screen.pcInput, on: item.screen.monitor) {
                gone.append(.init(monitor: item.screen.monitor, display: item.id, macInput: prefs.screen(item.screen.monitor)?.macInput))
            } else {
                note = "\(item.screen.monitor.name) didn't switch to \(prefs.pcLabel)."
            }
        }
        guard !gone.isEmpty else {
            windows.forget()
            return
        }

        prefs.handover = Handover(away: gone, layout: snapshot, keyboardOnPC: switchSpot == .pc)
        // turn them off before touching the layout, or macOS saves this layout as the everyday one
        for away in gone {
            guard let id = away.display, !displays.setEnabled(id, false) else { continue }
            prefs.handover?.setDisplay(nil, for: away.monitor)
            log.error("macOS refused to turn off \(away.monitor.name, privacy: .public)")
            note = "\(away.monitor.name) is on \(prefs.pcLabel), but macOS is still using it."
        }
        await settleRotation(for: .seconds(3))
        if !displays.isMain(plan.home.id) {
            displays.makeMain(plan.home.id)
            await clock.sleep(for: .milliseconds(300))
        }
        for screen in plan.remaining {
            windows.restore(on: screen.monitor)
        }
        mode = .pc
        await syncOptional()
    }

    /// nil after saying why it can't be done.
    private func planHandover() -> HandoverPlan? {
        let screens = displays.screens()
        let going = prefs.screens.filter { $0.role == .goes }
        guard !going.isEmpty else {
            note = "Pick a screen to share in Settings."
            return nil
        }
        let leaving = going.compactMap { screen in
            screens.first { $0.monitor == screen.monitor }.map { HandoverPlan.Leaving(screen: screen, id: $0.id) }
        }
        guard !leaving.isEmpty else {
            note = "\(going[0].monitor.name) isn't connected."
            return nil
        }
        // never leave the Mac without a screen
        let remaining = screens.filter { screen in !leaving.contains { $0.id == screen.id } }
        guard let home = homeScreen(among: remaining) else {
            note = "The Mac needs another screen before it can give \(leaving[0].screen.monitor.name) away."
            return nil
        }
        return HandoverPlan(leaving: leaving, remaining: remaining, home: home)
    }

    func takeBack(_ reason: String) async {
        guard mode == .pc, !busy else { return }
        busy = true
        defer { busy = false }
        log.notice("taking back: \(reason, privacy: .public)")
        note = nil

        let away = prefs.handover?.away ?? []
        let disabled = away.compactMap(\.display)
        disabled.forEach { displays.setEnabled($0, true) }
        await waitUntilActive(disabled)

        // the DDC service comes back a beat after the display does, so give it more tries
        for screen in away {
            guard let input = screen.macInput ?? prefs.screen(screen.monitor)?.macInput,
                  await setInput(input, on: screen.monitor, attempts: 6) else {
                note = "\(screen.monitor.name) didn't switch back. Use the input button on the monitor."
                strays[screen.monitor] = 8
                continue
            }
        }
        // the ones that stayed can drift over too if they lost the Mac's signal
        for screen in prefs.screens where !away.contains(where: { $0.monitor == screen.monitor }) {
            await ensureInput(screen.macInput, on: screen.monitor)
        }
        if let snapshot = prefs.handover?.layout {
            await clock.sleep(for: .milliseconds(500))
            displays.restore(snapshot)
        }
        await settleRotation(for: .seconds(1))
        windows.restoreAll()
        windows.forget()
        lentWindows.forget()
        prefs.handover = nil
        mode = .mac
        layout = displays.snapshot()
    }

    // MARK: - Optional screens

    /// Optional screens go with the keyboard, so switching back mid-session gives the Mac something to show.
    private var optionalBelongOnPC: Bool {
        mode == .pc && prefs.everyScreen && prefs.hasOptional
            && (!prefs.followSwitch || prefs.switchDevice == nil || switchSpot == .pc)
    }

    func syncOptional() async {
        // the keyboard can move again while a hand-off is running, so look once more after
        for _ in 0..<2 {
            let wanted = optionalBelongOnPC
            guard wanted != everyScreenAway else { return }
            if wanted {
                await lendOptional()
            } else {
                await reclaimOptional()
            }
        }
    }

    func resyncOptional() async {
        guard mode == .pc, !busy else { return }
        busy = true
        defer { busy = false }
        await syncOptional()
    }

    /// With another screen to fall back to (an open laptop), macOS turns these off.
    /// Without one the last stays on, out of sight, so the Mac is still there when it comes back.
    private func lendOptional() async {
        let connected = displays.screens()
        let items = prefs.screens
            .filter { $0.role == .optional }
            .compactMap { screen in connected.first { $0.monitor == screen.monitor }.map { (screen: screen, id: $0.id) } }
            .sorted { !displays.isMain($0.id) && displays.isMain($1.id) }
        guard !items.isEmpty else { return }
        await learnInputs()

        let fallback = connected.contains { screen in
            !items.contains { $0.id == screen.id } && !(prefs.handover?.has(screen.monitor) ?? false)
        }
        if fallback { lentWindows.capture() }
        var lent = 0
        for (index, item) in items.enumerated() {
            guard await setInput(item.screen.pcInput, on: item.screen.monitor) else {
                note = "\(item.screen.monitor.name) didn't switch to \(prefs.pcLabel)."
                continue
            }
            log.notice("\(item.screen.monitor.name, privacy: .public) went over too")
            lent += 1
            prefs.handover?.away.append(.init(monitor: item.screen.monitor, optional: true, macInput: prefs.screen(item.screen.monitor)?.macInput))
            if fallback || index < items.count - 1, displays.setEnabled(item.id, false) {
                prefs.handover?.setDisplay(item.id, for: item.screen.monitor)
            }
        }
        if lent == 0 { lentWindows.forget() }
    }

    private func reclaimOptional() async {
        let lent = prefs.handover?.away.filter(\.optional) ?? []
        let disabled = lent.compactMap(\.display)
        for away in lent where away.display != nil {
            away.display.map { _ = displays.setEnabled($0, true) }
            prefs.handover?.setDisplay(nil, for: away.monitor)
        }
        await waitUntilActive(disabled)

        var returned = [MonitorID]()
        for screen in lent {
            let monitor = screen.monitor
            guard let input = screen.macInput ?? prefs.screen(monitor)?.macInput,
                  await setInput(input, on: monitor, attempts: 6) else {
                note = "\(monitor.name) didn't come back. Use the input button on the monitor."
                continue
            }
            log.notice("\(monitor.name, privacy: .public) came back to the Mac")
            prefs.handover?.away.removeAll { $0.monitor == monitor }
            returned.append(monitor)
        }
        guard !disabled.isEmpty, !returned.isEmpty else { return }
        await settleRotation(for: .seconds(2))
        await makeHomeMain()
        for monitor in returned {
            lentWindows.restore(on: monitor)
        }
        lentWindows.forget()
    }

    // MARK: - Helpers

    /// Where the menu bar lives while other screens are away.
    func homeScreen(among screens: [ScreenInfo]) -> ScreenInfo? {
        let preferred = prefs.screens.filter { $0.role != .goes }.sorted { $0.role == .optional && $1.role != .optional }
        return preferred.lazy.compactMap { screen in screens.first { $0.monitor == screen.monitor } }.first
            ?? screens.first { !$0.isBuiltin }
            ?? screens.first
    }

    func makeHomeMain() async {
        let here = displays.screens().filter { !(prefs.handover?.has($0.monitor) ?? false) }
        guard let home = homeScreen(among: here), !displays.isMain(home.id) else { return }
        displays.makeMain(home.id)
        await clock.sleep(for: .milliseconds(300))
    }

    func waitUntilActive(_ ids: [CGDirectDisplayID]) async {
        var waited = 0
        while !ids.allSatisfy({ displays.isActive($0) }) && waited < 20 {
            await clock.sleep(for: .milliseconds(250))
            waited += 1
        }
    }
}

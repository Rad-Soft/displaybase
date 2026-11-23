//
//  DeskController+Screens.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import AppKit

extension DeskController {
    func displaysChanged(added: Bool) {
        // closing the lid with every other screen lent out would leave macOS with none
        if displays.online().isEmpty, let away = prefs.handover?.away.last(where: { $0.optional && $0.display != nil }) {
            away.display.map { _ = displays.setEnabled($0, true) }
            prefs.handover?.setDisplay(nil, for: away.monitor)
        }
        screenCameBack = screenCameBack || added
        reconfigureTask?.cancel()
        reconfigureTask = Task {
            await clock.sleep(for: .seconds(1))
            guard !Task.isCancelled, !busy else { return }
            holdRotation()
            if screenCameBack {
                screenCameBack = false
                await uninterrupted { [self] in await screensReconnected() }
            }
            if mode == .mac { layout = displays.snapshot() }
        }
    }

    /// A monitor that loses the Mac's signal (dock replug, cable bump) hops inputs on its own,
    /// and a screen that was turned off comes back on, so put each where it belongs.
    private func screensReconnected() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        log.notice("screens reconnected, checking inputs")

        for screen in prefs.screens {
            guard let away = prefs.handover?.away.first(where: { $0.monitor == screen.monitor }) else {
                await ensureInput(screen.macInput, on: screen.monitor)
                continue
            }
            await ensureInput(screen.pcInput, on: screen.monitor)
            if !away.optional || away.display != nil, displays.online().count > 1,
               let id = displays.display(matching: screen.monitor), displays.setEnabled(id, false) {
                prefs.handover?.setDisplay(id, for: screen.monitor)
            }
        }
        guard mode == .pc else { return }
        await settleRotation(for: .seconds(2))
        await makeHomeMain()
    }

    /// Keeps trying a screen that didn't switch back, without fighting anyone who moved it on purpose.
    func fetchStrays() async {
        guard mode == .mac, !busy, !strays.isEmpty else { return }
        busy = true
        defer { busy = false }
        for (monitor, tries) in strays {
            guard let input = prefs.screen(monitor)?.macInput, tries > 0 else {
                strays[monitor] = nil
                continue
            }
            if await setInput(input, on: monitor, attempts: 1) {
                strays[monitor] = nil
                note = nil
            } else {
                strays[monitor] = tries - 1
            }
        }
    }

    // MARK: - Inputs

    func currentInput(of monitor: MonitorID) async -> Int? {
        await monitors.readInput(of: monitor)
    }

    func learnInputs() async {
        for screen in prefs.screens where !(prefs.handover?.has(screen.monitor) ?? false) {
            guard let current = await currentInput(of: screen.monitor), current != screen.pcInput else { continue }
            prefs.update(screen.monitor) { $0.macInput = current }
        }
    }

    func ensureInput(_ value: Int?, on monitor: MonitorID) async {
        guard let value, let current = await currentInput(of: monitor), current != value else { return }
        log.notice("\(monitor.name, privacy: .public) wandered to input 0x\(String(current, radix: 16), privacy: .public), switching it back")
        _ = await setInput(value, on: monitor)
    }

    func setInput(_ value: Int, on monitor: MonitorID, attempts: Int = 4) async -> Bool {
        for attempt in 0..<attempts {
            if attempt > 0 { await clock.sleep(for: .milliseconds(1500)) }
            guard await monitors.writeInput(value, on: monitor) else { continue }
            await clock.sleep(for: .seconds(1))
            if await currentInput(of: monitor) == value { return true }
        }
        log.error("input 0x\(String(value, radix: 16), privacy: .public) didn't stick on \(monitor.name, privacy: .public)")
        return false
    }

    // MARK: - Rotation

    /// macOS keeps a separate layout for every set of screens it has seen, and a new set comes up unrotated.
    @discardableResult
    func holdRotation() -> Bool {
        var turned = false
        for screen in prefs.screens {
            guard let pinned = screen.rotation, let id = displays.display(matching: screen.monitor),
                  displays.rotation(of: id) != pinned else { continue }
            log.notice("rotating \(screen.monitor.name, privacy: .public) back to \(pinned)°")
            if displays.setRotation(pinned, on: id) { turned = true }
        }
        return turned
    }

    /// Rotates back the moment macOS resets it, instead of after it has already reflowed windows.
    func settleRotation(for duration: Duration) async {
        guard prefs.screens.contains(where: { $0.rotation != nil }) else { return }
        let deadline = clock.now + duration
        while clock.now < deadline {
            await clock.sleep(for: holdRotation() ? .milliseconds(500) : .milliseconds(150))
        }
    }
}

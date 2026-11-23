//
//  DeskController+Switch.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

extension DeskController {
    func watchSwitchDevice() {
        usb.watch(prefs.switchDevice)
        followTask?.cancel()
        if usb.isPresent {
            switchSpot = .mac
        } else {
            switchSpot = .unknown
            followTask = Task { switchSpot = await locateSwitch() ?? .unknown }
        }
    }

    func switchMoved(toMac present: Bool) {
        log.notice("switch device \(present ? "arrived on" : "left", privacy: .public) the Mac")
        followTask?.cancel()
        if present {
            switchSpot = .mac
            if prefs.followSwitch, prefs.switchBackTakesBack, mode == .pc {
                Task {
                    await whenIdle()
                    await takeBack("switch came back")
                }
            } else {
                Task {
                    await whenIdle()
                    await resyncOptional()
                }
            }
            return
        }
        switchSpot = .unknown
        followTask = Task { await followSwitch() }
    }

    /// The device left the Mac. When the other computer can be asked, only hand over once it confirms it
    /// has it, so pressing the wrong button can't take the screen away.
    private func followSwitch() async {
        for _ in 0..<5 {
            await clock.sleep(for: .milliseconds(1500))
            if Task.isCancelled { return }
            guard await locateSwitch() == .pc else { continue }
            switchSpot = .pc
            prefs.handover?.keyboardOnPC = true
            await whenIdle()
            if Task.isCancelled { return }
            await uninterrupted { [self] in
                if prefs.followSwitch, mode == .mac {
                    await handOver("switch moved")
                } else {
                    await resyncOptional()
                }
            }
            return
        }
        guard !Task.isCancelled else { return }
        switchSpot = .elsewhere
        await warnIfSwitchLost(after: .seconds(15))
    }

    private func locateSwitch() async -> SwitchSpot? {
        if usb.isPresent { return .mac }
        guard let device = prefs.switchDevice else { return nil }
        // nothing to ask, so leaving the Mac has to be good enough
        guard prefs.hasRemote else { return .pc }
        guard let onPC = await remote.has(device, host: prefs.remoteHost, system: prefs.remoteSystem) else { return nil }
        return onPC ? .pc : .elsewhere
    }

    func warnIfSwitchLost(after delay: Duration) async {
        await clock.sleep(for: delay)
        guard !Task.isCancelled, !usb.isPresent else { return }
        switchSpot = .elsewhere
        log.error("switch is on neither machine")
        // bring the Mac's screen home so this has somewhere to show
        await uninterrupted { [self] in await resyncOptional() }
        notify(
            "Your switch isn't on either computer",
            "Its USB port may have dropped. Unplug the cable or dock it uses and plug it back in."
        )
    }
}

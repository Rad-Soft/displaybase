//
//  LostSwitchTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct LostSwitchTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    @Test("a switch on neither computer produces a warning with the fix")
    func warns() async {
        desk.useSwitch()
        await controller.warnIfSwitchLost(after: .seconds(8))
        #expect(desk.notifications.count == 1)
        #expect(desk.notifications[0].title == "Your switch isn't on either computer")
        #expect(desk.notifications[0].body == "Its USB port may have dropped. Unplug the cable or dock it uses and plug it back in.")
        #expect(controller.switchSpot == .elsewhere)
        #expect(desk.clock.sleeps == [.seconds(8)])
    }

    @Test("no warning when the device turned up on the Mac in the meantime")
    func backOnTheMac() async {
        desk.useSwitch()
        desk.usb.startPresent(true)
        await controller.warnIfSwitchLost(after: .seconds(8))
        #expect(desk.notifications.isEmpty && controller.switchSpot == .unknown)
    }

    @Test("or when it was canceled because the situation changed")
    func canceled() async {
        desk.useSwitch()
        let task = Task { await controller.warnIfSwitchLost(after: .seconds(8)) }
        task.cancel()
        await task.value
        #expect(desk.notifications.isEmpty)
    }

    @Test("the Mac's screens come home before the warning, so it has somewhere to show")
    func screensComeHome() async {
        desk.add("Goes", role: .goes)
        desk.add("Stay")
        desk.add("Extra", role: .optional)
        desk.prefs.everyScreen = true
        desk.useSwitch()
        controller.switchSpot = .pc
        await controller.handOver("shortcut")
        #expect(!desk.display("Extra").active)

        await controller.warnIfSwitchLost(after: .seconds(15))
        #expect(desk.display("Extra").active && desk.monitor("Extra").input == 0x0F)
        #expect(desk.log.happened("ddc Extra 0xf", before: "notify Your switch isn't on either computer"))
        #expect(controller.mode == .pc)
    }

    @Test("polling raises the warning when the other computer stops having the keyboard")
    func fromPolling() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        desk.useSwitch(askRemote: true)
        controller.switchSpot = .pc
        await controller.handOver("shortcut")
        desk.remote.hasDevice = false
        _ = await controller.pollOnce()
        #expect(desk.notifications.isEmpty)
        _ = await controller.pollOnce()
        await controller.followTask?.value
        #expect(desk.prefs.handover?.keyboardOnPC == false)
        #expect(desk.notifications.map(\.title) == ["Your switch isn't on either computer"])
        #expect(controller.mode == .pc)
    }
}

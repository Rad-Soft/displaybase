//
//  LidTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct LidTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    /// Goes is on the other computer and Extra is lent out, so the laptop is all the Mac has.
    func everythingLentOut() async {
        desk.add("Goes", role: .goes)
        desk.add("Extra", role: .optional)
        desk.addLaptop()
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
    }

    @Test("closing the lid with everything lent out brings the last lent screen back")
    func closingTheLid() async {
        await everythingLentOut()
        #expect(!desk.display("Extra").active)

        desk.displays.closeLid()
        controller.displaysChanged(added: false)

        #expect(desk.display("Extra").active)
        let extra = desk.prefs.handover?.away.first { $0.monitor == desk.id("Extra") }
        #expect(extra?.display == nil && extra?.optional == true)
        // still lent: the monitor is on the other computer's input, only macOS has it back
        #expect(desk.monitor("Extra").input == 0x11)
        await controller.reconfigureTask?.value
        #expect(!controller.busy && controller.mode == .pc)
    }

    @Test("with another screen still on, the lid does nothing special")
    func otherScreenOn() async {
        desk.add("Goes", role: .goes)
        desk.add("Extra", role: .optional)
        desk.add("Stay")
        desk.addLaptop()
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        desk.log.clear()
        desk.displays.closeLid()
        controller.displaysChanged(added: false)
        #expect(!desk.display("Extra").active && desk.log.events.isEmpty)
    }

    @Test("a lent screen that never turned off isn't touched")
    func neverTurnedOff() async {
        desk.add("Goes", role: .goes)
        desk.add("Extra", role: .optional)
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        desk.log.clear()
        // nothing is online only if it really isn't, so pretend macOS lost it
        desk.display("Extra").active = false
        controller.displaysChanged(added: false)
        #expect(!desk.log.contains("enable Extra"))
    }

    @Test("when only the screens set to go are away, there's nothing to bring back")
    func nothingLent() async {
        desk.add("Goes", role: .goes)
        desk.addLaptop()
        await controller.handOver("shortcut")
        desk.log.clear()
        desk.displays.closeLid()
        controller.displaysChanged(added: false)
        #expect(desk.log.events.isEmpty)
    }

    @Test("with two lent screens, one is enough to keep the Mac from having none")
    func oneLentComesBack() async {
        desk.add("Goes", role: .goes)
        desk.add("First", role: .optional)
        desk.add("Second", role: .optional)
        desk.addLaptop()
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        #expect(!desk.display("First").active && !desk.display("Second").active)
        desk.displays.closeLid()
        controller.displaysChanged(added: false)
        #expect(desk.displays.online().count == 1)
        #expect(desk.display("First").active && !desk.display("Second").active)
    }

    @Test("opening the lid again is treated as a screen coming back")
    func openingTheLid() async {
        await everythingLentOut()
        desk.displays.closeLid()
        controller.displaysChanged(added: false)
        await controller.reconfigureTask?.value
        desk.displays.openLid()
        controller.displaysChanged(added: true)
        await controller.reconfigureTask?.value
        #expect(controller.mode == .pc && !controller.busy)
        #expect(desk.monitor("Goes").input == 0x11)
    }
}

//
//  SwitchFollowTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct SwitchFollowTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    func twoScreens() {
        desk.add("Left", role: .goes)
        desk.add("Right")
    }

    func keyboardLeaves() async {
        desk.usb.plug(false)
        await controller.followTask?.value
    }

    // MARK: - Asking the other computer

    @Test("with ssh, the screens go once the other computer confirms it has the keyboard")
    func confirmed() async {
        twoScreens()
        desk.useSwitch(askRemote: true)
        desk.usb.startPresent(true)
        desk.remote.hasDevice = true
        await keyboardLeaves()

        #expect(controller.mode == .pc && controller.switchSpot == .pc)
        #expect(desk.prefs.handover?.keyboardOnPC == true)
        #expect(desk.remote.deviceChecks == 1)
        #expect(desk.monitor("Left").input == 0x11)
        #expect(desk.clock.sleeps.first == .milliseconds(1500))
    }

    @Test("when the other computer says it doesn't have the keyboard, nothing moves and a warning shows")
    func denied() async {
        twoScreens()
        desk.useSwitch(askRemote: true)
        desk.remote.hasDevice = false
        await keyboardLeaves()

        #expect(controller.mode == .mac && desk.prefs.handover == nil)
        #expect(controller.switchSpot == .elsewhere)
        #expect(desk.remote.deviceChecks == 5)
        #expect(desk.monitor("Left").writes.isEmpty)
        #expect(desk.notifications.count == 1)
        #expect(desk.clock.sleeps.contains(.seconds(15)))
    }

    @Test("when it can't be asked, that's treated the same, never as permission")
    func cannotAsk() async {
        twoScreens()
        desk.useSwitch(askRemote: true)
        desk.remote.hasDevice = nil
        await keyboardLeaves()

        #expect(controller.mode == .mac && controller.switchSpot == .elsewhere)
        #expect(desk.remote.deviceChecks == 5)
        #expect(desk.notifications.map(\.title) == ["Your switch isn't on either computer"])
        #expect(desk.monitor("Left").writes.isEmpty)
    }

    @Test("a slow switch is waited for, up to five tries")
    func slowSwitch() async {
        twoScreens()
        desk.useSwitch(askRemote: true)
        desk.remote.hasDevice = false
        desk.usb.plug(false)
        await settle("two checks") { desk.remote.deviceChecks == 2 }
        desk.remote.hasDevice = true
        await controller.followTask?.value
        #expect(controller.mode == .pc && desk.notifications.isEmpty)
        #expect(desk.remote.deviceChecks == 3)
    }

    @Test("without ssh, the keyboard leaving is good enough")
    func withoutSSH() async {
        twoScreens()
        desk.useSwitch()
        desk.usb.startPresent(true)
        await keyboardLeaves()
        #expect(controller.mode == .pc && controller.switchSpot == .pc)
        #expect(desk.remote.deviceChecks == 0)
        #expect(desk.monitor("Left").input == 0x11)
    }

    @Test("with following off, the keyboard moving doesn't move the screens")
    func followingOff() async {
        twoScreens()
        desk.useSwitch()
        desk.prefs.followSwitch = false
        await keyboardLeaves()
        #expect(controller.mode == .mac && controller.switchSpot == .pc)
        #expect(desk.log.events.isEmpty)
    }

    @Test("a device that flickers off and straight back moves nothing")
    func flicker() async {
        twoScreens()
        desk.useSwitch(askRemote: true)
        desk.usb.plug(false)
        desk.usb.plug(true)
        await controller.followTask?.value
        #expect(controller.mode == .mac && controller.switchSpot == .mac)
        #expect(desk.remote.deviceChecks == 0 && desk.notifications.isEmpty)
        #expect(desk.log.events.isEmpty)
    }

    // MARK: - Coming back

    @Test("with switch-back taking back, the keyboard returning brings everything home")
    func takesBack() async {
        twoScreens()
        desk.useSwitch(takesBack: true)
        await keyboardLeaves()
        #expect(controller.mode == .pc)

        desk.usb.plug(true)
        await settle("take-back") { controller.mode == .mac }
        #expect(desk.monitor("Left").input == 0x0F && desk.display("Left").active)
        #expect(controller.switchSpot == .mac && desk.prefs.handover == nil)
    }

    @Test("without it, the keyboard returning only borrows the Mac's keyboard back")
    func doesNotTakeBack() async {
        twoScreens()
        desk.useSwitch(takesBack: false)
        await keyboardLeaves()
        desk.log.clear()

        desk.usb.plug(true)
        await drain()
        #expect(controller.mode == .pc && controller.switchSpot == .mac)
        #expect(!desk.log.contains("enable Left") && desk.prefs.handover != nil)
        #expect(desk.monitor("Left").input == 0x11)
    }

    @Test("with following off, the keyboard returning leaves things alone even if it would take back")
    func followingOffNoTakeBack() async {
        twoScreens()
        desk.useSwitch(takesBack: true)
        await keyboardLeaves()
        desk.prefs.followSwitch = false
        desk.usb.plug(true)
        await drain()
        #expect(controller.mode == .pc && desk.display("Left").active == false)
    }

    @Test("the keyboard arriving when nothing is away does nothing")
    func nothingAway() async {
        twoScreens()
        desk.useSwitch(takesBack: true)
        desk.usb.plug(true)
        await drain()
        #expect(controller.mode == .mac && desk.log.events.isEmpty && controller.switchSpot == .mac)
    }

    @Test("a flicker in the middle of a hand-over doesn't interrupt it, even if switch-back takes back")
    func flickerDuringHandOver() async {
        twoScreens()
        desk.useSwitch(takesBack: true)
        desk.usb.startPresent(true)
        let handOver = Task { await controller.handOver("shortcut") }
        await settle("hand-over to start") { controller.busy }

        desk.usb.plug(false)
        desk.usb.plug(true)
        await handOver.value
        await drain()

        #expect(controller.mode == .pc && desk.prefs.handover != nil)
        #expect(desk.log.count(of: "ddc Left 0x11") == 1)
        #expect(!desk.log.contains("enable Left") && !desk.log.contains("restore layout"))
        #expect(desk.monitor("Left").input == 0x11 && !desk.display("Left").active)
    }

    @Test("the keyboard leaving during a hand-over doesn't start a second one")
    func leavingDuringHandOver() async {
        twoScreens()
        desk.useSwitch()
        desk.usb.startPresent(true)
        let handOver = Task { await controller.handOver("shortcut") }
        await settle("hand-over to start") { controller.busy }
        desk.usb.plug(false)
        await handOver.value
        await controller.followTask?.value

        #expect(controller.mode == .pc && controller.switchSpot == .pc)
        #expect(desk.prefs.handover?.keyboardOnPC == true)
        #expect(desk.log.count(of: "ddc Left 0x11") == 1 && desk.log.count(of: "disable Left") == 1)
    }

    // MARK: - Finding out where it is

    @Test("a device that's here at launch means the keyboard is on the Mac")
    func presentAtLaunch() {
        desk.useSwitch()
        desk.usb.startPresent(true)
        controller.watchSwitchDevice()
        #expect(controller.switchSpot == .mac)
        #expect(desk.usb.watched == desk.prefs.switchDevice)
    }

    @Test("with no switch device chosen, there's nothing to find")
    func noDevice() async {
        controller.watchSwitchDevice()
        await controller.followTask?.value
        #expect(controller.switchSpot == .unknown && desk.usb.watched == nil)
    }

    @Test("a device that's missing at launch is looked for over ssh, or assumed gone to the other computer")
    func missingAtLaunch() async {
        desk.useSwitch(askRemote: true)
        desk.remote.hasDevice = true
        controller.watchSwitchDevice()
        await controller.followTask?.value
        #expect(controller.switchSpot == .pc)

        desk.remote.hasDevice = false
        controller.watchSwitchDevice()
        await controller.followTask?.value
        #expect(controller.switchSpot == .elsewhere)

        desk.remote.hasDevice = nil
        controller.watchSwitchDevice()
        await controller.followTask?.value
        #expect(controller.switchSpot == .unknown)

        desk.prefs.remoteHost = ""
        controller.watchSwitchDevice()
        await controller.followTask?.value
        #expect(controller.switchSpot == .pc)
    }
}

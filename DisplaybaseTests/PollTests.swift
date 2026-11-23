//
//  PollTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct PollTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    func handedOver(askRemote: Bool = true) async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        if askRemote { desk.prefs.remoteHost = "gaming" }
        await controller.handOver("shortcut")
    }

    @Test("without a remote host there's nothing to ask and nothing is shown")
    func noRemote() async {
        controller.pcOnline = true
        let wait = await controller.pollOnce()
        #expect(controller.pcOnline == nil && wait == .seconds(15))
        #expect(desk.remote.reachableChecks == 0)
    }

    @Test("it tells whether the other computer is up, and checks slowly while the Mac has everything")
    func online() async {
        desk.prefs.remoteHost = "gaming"
        var wait = await controller.pollOnce()
        #expect(controller.pcOnline == true && wait == .seconds(15))
        desk.remote.online = false
        wait = await controller.pollOnce()
        #expect(controller.pcOnline == false && wait == .seconds(15) && controller.mode == .mac)
    }

    @Test("it checks more often while the screens are over there")
    func quicker() async {
        await handedOver()
        let wait = await controller.pollOnce()
        #expect(wait == .seconds(4))
    }

    @Test("permission to move windows is kept up to date")
    func windowsAllowed() async {
        desk.windows.isTrusted = false
        _ = await controller.pollOnce()
        #expect(!controller.windowsAllowed)
        desk.windows.isTrusted = true
        _ = await controller.pollOnce()
        #expect(controller.windowsAllowed)
    }

    @Test("the Mac takes everything back after the other computer is seen up and then three polls offline")
    func wentOffline() async {
        await handedOver()
        _ = await controller.pollOnce()
        desk.remote.online = false
        _ = await controller.pollOnce()
        _ = await controller.pollOnce()
        #expect(controller.mode == .pc)
        let wait = await controller.pollOnce()
        #expect(controller.mode == .mac && wait == .seconds(15))
        #expect(desk.monitor("Left").input == 0x0F && desk.display("Left").active)
    }

    @Test("a computer that was never seen online is given time to boot")
    func neverSeen() async {
        desk.remote.online = false
        await handedOver()
        for _ in 0..<10 { _ = await controller.pollOnce() }
        #expect(controller.mode == .pc && controller.pcOnline == false)
    }

    @Test("a computer coming back online starts the count over")
    func flaky() async {
        await handedOver()
        _ = await controller.pollOnce()
        desk.remote.online = false
        _ = await controller.pollOnce()
        _ = await controller.pollOnce()
        desk.remote.online = true
        _ = await controller.pollOnce()
        desk.remote.online = false
        _ = await controller.pollOnce()
        _ = await controller.pollOnce()
        #expect(controller.mode == .pc)
    }

    @Test("what was seen before the Mac took things back doesn't carry into the next hand-over")
    func forgetsBetweenHandOvers() async {
        await handedOver()
        _ = await controller.pollOnce()
        await controller.takeBack("shortcut")
        _ = await controller.pollOnce()
        await controller.handOver("shortcut")
        desk.remote.online = false
        for _ in 0..<5 { _ = await controller.pollOnce() }
        #expect(controller.mode == .pc)
    }

    @Test("nothing is taken back mid-hand-over")
    func notWhileBusy() async {
        await handedOver()
        _ = await controller.pollOnce()
        desk.remote.online = false
        controller.busy = true
        for _ in 0..<5 { _ = await controller.pollOnce() }
        #expect(controller.mode == .pc)
    }

    // MARK: - The switch device

    func keyboardOnPC(takesBack: Bool = false) async {
        desk.useSwitch(askRemote: true, takesBack: takesBack)
        controller.switchSpot = .pc
        await handedOver()
    }

    @Test("when the other computer stops having the keyboard twice running, the Mac notes it")
    func lostKeyboard() async {
        await keyboardOnPC()
        desk.remote.hasDevice = false
        _ = await controller.pollOnce()
        #expect(desk.prefs.handover?.keyboardOnPC == true)
        _ = await controller.pollOnce()
        #expect(desk.prefs.handover?.keyboardOnPC == false)
        await controller.followTask?.value
        #expect(controller.mode == .pc && desk.notifications.count == 1)
    }

    @Test("with switch-back taking back, that also takes everything back")
    func lostKeyboardTakesBack() async {
        await keyboardOnPC(takesBack: true)
        desk.remote.hasDevice = false
        _ = await controller.pollOnce()
        _ = await controller.pollOnce()
        #expect(controller.mode == .mac && desk.prefs.handover == nil)
        #expect(desk.monitor("Left").input == 0x0F)
    }

    @Test("one miss between hits isn't enough")
    func blip() async {
        await keyboardOnPC()
        desk.remote.hasDevice = false
        _ = await controller.pollOnce()
        desk.remote.hasDevice = true
        _ = await controller.pollOnce()
        desk.remote.hasDevice = false
        _ = await controller.pollOnce()
        #expect(desk.prefs.handover?.keyboardOnPC == true)
    }

    @Test("an answer that can't be had counts as neither")
    func unanswered() async {
        await keyboardOnPC()
        desk.remote.hasDevice = nil
        for _ in 0..<5 { _ = await controller.pollOnce() }
        #expect(desk.prefs.handover?.keyboardOnPC == true && desk.notifications.isEmpty)
        #expect(desk.remote.deviceChecks == 5)
    }

    @Test("the keyboard isn't asked about when it's here, when it isn't followed, or when the other computer is down")
    func notAsked() async {
        await keyboardOnPC()
        desk.usb.startPresent(true)
        _ = await controller.pollOnce()
        #expect(desk.remote.deviceChecks == 0)

        desk.usb.startPresent(false)
        desk.prefs.followSwitch = false
        _ = await controller.pollOnce()
        #expect(desk.remote.deviceChecks == 0)

        desk.prefs.followSwitch = true
        desk.remote.online = false
        _ = await controller.pollOnce()
        #expect(desk.remote.deviceChecks == 0)
    }

    @Test("or when it was never known to be over there")
    func keyboardNeverThere() async {
        desk.useSwitch(askRemote: true)
        await handedOver()
        _ = await controller.pollOnce()
        #expect(desk.prefs.handover?.keyboardOnPC == false && desk.remote.deviceChecks == 0)
    }

    // MARK: - The loop

    @Test("starting begins polling and keeps going at the right pace")
    func loop() async {
        desk.prefs.remoteHost = "gaming"
        controller.start()
        await settle("a few polls") { desk.remote.reachableChecks >= 3 }
        #expect(desk.clock.sleeps.contains(.seconds(15)))
        #expect(controller.pcOnline == true)
    }
}

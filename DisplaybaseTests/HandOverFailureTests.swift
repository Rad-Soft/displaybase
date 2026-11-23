//
//  HandOverFailureTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct HandOverFailureTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    @Test("the Mac never gives away its only screen")
    func lastScreen() async {
        desk.add("Only", role: .goes)
        await controller.handOver("shortcut")
        #expect(controller.note == "The Mac needs another screen before it can give Only away.")
        #expect(controller.mode == .mac && desk.prefs.handover == nil && !controller.busy)
        #expect(desk.log.events.isEmpty)
        #expect(desk.display("Only").active)
    }

    @Test("or every screen, when all of them are set to go")
    func everyScreenGoes() async {
        desk.add("First", role: .goes)
        desk.add("Second", role: .goes)
        await controller.handOver("shortcut")
        #expect(controller.note == "The Mac needs another screen before it can give First away.")
        #expect(desk.log.events.isEmpty)
        #expect(desk.displays.online().count == 2)
    }

    @Test("a closed laptop doesn't count as a screen to keep")
    func closedLid() async {
        desk.add("Left", role: .goes)
        desk.addLaptop()
        desk.displays.closeLid()
        await controller.handOver("shortcut")
        #expect(controller.note == "The Mac needs another screen before it can give Left away.")
        #expect(desk.display("Left").active && controller.mode == .mac)
    }

    @Test("a screen that isn't connected says so")
    func notConnected() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        desk.display("Left").active = false
        await controller.handOver("shortcut")
        #expect(controller.note == "Left isn't connected.")
        #expect(controller.mode == .mac && desk.log.events.isEmpty)
    }

    @Test("nothing set to go points to settings")
    func nothingSet() async {
        desk.add("Left")
        desk.add("Right", role: .optional)
        await controller.handOver("shortcut")
        #expect(controller.note == "Pick a screen to share in Settings.")
        #expect(desk.log.events.isEmpty)
    }

    @Test("a monitor that refuses stays on the Mac and nothing else changes")
    func refuses() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        left.refusesSwitch = true
        await controller.handOver("shortcut")

        #expect(controller.mode == .mac && desk.prefs.handover == nil && !controller.busy)
        #expect(controller.note == "Left didn't switch to PC.")
        #expect(left.writes == [0x11, 0x11, 0x11, 0x11])
        #expect(desk.clock.sleeps.filter { $0 == .milliseconds(1500) }.count == 3)
        #expect(desk.display("Left").active)
        #expect(!desk.log.contains("disable Left") && !desk.log.contains("main Right"))
        #expect(desk.log.happened("windows capture", before: "windows forget"))
        #expect(!desk.log.events.contains { $0.hasPrefix("windows restore") })
    }

    @Test("a monitor that ignores the first writes still gets there on a retry")
    func ignoresAtFirst() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        left.ignoredWrites = 2
        await controller.handOver("shortcut")
        #expect(controller.mode == .pc)
        #expect(left.writes.count == 3 && left.input == 0x11)
        #expect(controller.note == nil)
    }

    @Test("but not when it ignores more than the retries allow")
    func ignoresTooLong() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        left.ignoredWrites = 4
        await controller.handOver("shortcut")
        #expect(controller.mode == .mac)
        #expect(left.writes.count == 4 && left.input == 0x0F)
    }

    @Test("when one of two refuses, the other still goes")
    func partial() async {
        let left = desk.add("Left", role: .goes)
        let middle = desk.add("Middle", role: .goes)
        desk.add("Right")
        left.refusesSwitch = true
        await controller.handOver("shortcut")

        #expect(controller.mode == .pc)
        #expect(controller.note == "Left didn't switch to PC.")
        #expect(desk.prefs.handover?.away.map(\.monitor.name) == ["Middle"])
        #expect(middle.input == 0x11 && left.input == 0x0F)
        #expect(desk.display("Left").active && !desk.display("Middle").active)
        #expect(desk.log.contains("windows restore Right"))
    }

    @Test("macOS refusing to turn a screen off is noticed and remembered")
    func macOSRefuses() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        desk.display("Left").refusesDisable = true
        await controller.handOver("shortcut")

        #expect(controller.mode == .pc)
        #expect(controller.note == "Left is on PC, but macOS is still using it.")
        #expect(left.input == 0x11 && desk.display("Left").active)
        #expect(desk.prefs.handover?.away[0].display == nil)
        #expect(desk.prefs.handover?.has(desk.id("Left")) == true)

        // it was never turned off, so coming back doesn't try to turn it on
        await controller.takeBack("shortcut")
        #expect(!desk.log.contains("enable Left"))
        #expect(left.input == 0x0F && controller.mode == .mac)
    }

    @Test("one screen refusing to turn off doesn't stop the other")
    func oneRefusesOff() async {
        desk.add("Left", role: .goes)
        desk.add("Middle", role: .goes)
        desk.add("Right")
        desk.display("Left").refusesDisable = true
        await controller.handOver("shortcut")
        #expect(desk.prefs.handover?.away[0].display == nil)
        #expect(desk.prefs.handover?.away[1].display == desk.display("Middle").id)
        #expect(!desk.display("Middle").active)
    }

    @Test("the menu bar still moves to the screen that stays when the other one is stuck on")
    func menuBarWhenRefused() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        desk.display("Left").refusesDisable = true
        await controller.handOver("shortcut")
        #expect(desk.displays.main?.monitor.name == "Right")
        #expect(!desk.displays.lostEveryScreen)
    }
}

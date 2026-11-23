//
//  ReconnectTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct ReconnectTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    func reconnect(added: Bool = true) async {
        controller.displaysChanged(added: added)
        await controller.reconfigureTask?.value
    }

    @Test("when screens reconnect with the Mac in charge, every monitor goes back to the Mac's input")
    func macMode() async {
        let left = desk.add("Left", role: .goes)
        let right = desk.add("Right")
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        desk.prefs.update(desk.id("Right")) { $0.macInput = 0x0F }
        left.input = 0x11
        await reconnect()

        #expect(left.input == 0x0F && right.input == 0x0F)
        #expect(desk.log.contains("ddc Left 0xf") && !desk.log.events.contains { $0.hasPrefix("ddc Right") })
        #expect(!controller.busy && controller.mode == .mac)
    }

    @Test("a monitor with no known Mac input is left where it is")
    func unknownInput() async {
        let left = desk.add("Left")
        left.input = 0x11
        await reconnect()
        #expect(left.input == 0x11 && left.writes.isEmpty)
    }

    @Test("the layout is read again once things settle, with the Mac in charge")
    func layoutRefreshed() async {
        desk.add("Left")
        await reconnect(added: false)
        #expect(controller.layout.placements.map(\.monitor.name) == ["Left"])
        desk.display("Left").frame.origin = CGPoint(x: 100, y: 0)
        await reconnect(added: false)
        #expect(controller.layout.placements.first?.x == 100)
    }

    @Test("a screen going away isn't a reason to touch inputs")
    func removedOnly() async {
        let left = desk.add("Left")
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        left.input = 0x11
        await reconnect(added: false)
        #expect(left.writes.isEmpty)
    }

    @Test("with the other computer in charge, away screens go back to its input and off again")
    func pcMode() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")

        // a cable bump: the monitor hops to the Mac's input and macOS turns the screen back on
        left.input = 0x0F
        desk.display("Left").active = true
        desk.log.clear()
        await reconnect()

        #expect(left.input == 0x11 && !desk.display("Left").active)
        #expect(desk.prefs.handover?.away[0].display == desk.display("Left").id)
        #expect(desk.log.happened("ddc Left 0x11", before: "disable Left"))
        #expect(desk.displays.main?.monitor.name == "Right")
        #expect(controller.mode == .pc && !desk.displays.lostEveryScreen)
    }

    @Test("with the other computer in charge, the layout isn't read as the everyday one")
    func pcModeLayout() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        let before = controller.layout.placements.count
        desk.display("Right").frame.origin = CGPoint(x: 999, y: 0)
        await reconnect(added: false)
        #expect(controller.layout.placements.count == before)
        #expect(controller.layout.placements.first { $0.monitor.name == "Right" }?.x != 999)
    }

    @Test("an away screen that's the Mac's only one is left on")
    func onlyScreenOnline() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        desk.display("Left").active = true
        desk.display("Right").active = false
        await reconnect()
        #expect(desk.display("Left").active)
        #expect(desk.prefs.handover?.away[0].display == desk.display("Left").id)
    }

    @Test("an optional screen kept on out of sight isn't switched off by a reconnect")
    func optionalKeptOn() async {
        desk.add("Goes", role: .goes)
        desk.add("Extra", role: .optional)
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        desk.log.clear()
        await reconnect()
        #expect(desk.display("Extra").active && !desk.log.contains("disable Extra"))
        #expect(desk.monitor("Extra").input == 0x11)
    }

    @Test("an optional screen that was turned off goes back off")
    func optionalTurnedOff() async {
        desk.add("Goes", role: .goes)
        desk.add("Stay")
        desk.add("Extra", role: .optional)
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        desk.display("Extra").active = true
        await reconnect()
        #expect(!desk.display("Extra").active)
        #expect(desk.prefs.handover?.away.first { $0.optional }?.display == desk.display("Extra").id)
    }

    @Test("it doesn't run while a hand-over is going")
    func notWhileBusy() async {
        let left = desk.add("Left")
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        left.input = 0x11
        controller.busy = true
        await reconnect()
        #expect(left.writes.isEmpty)
        controller.busy = false
        // the reconnect wasn't forgotten, it runs with the next change
        await reconnect(added: false)
        #expect(left.input == 0x0F)
    }

    @Test("a burst of changes is one check")
    func burst() async {
        let left = desk.add("Left")
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        left.input = 0x11
        controller.displaysChanged(added: true)
        controller.displaysChanged(added: false)
        controller.displaysChanged(added: false)
        await controller.reconfigureTask?.value
        #expect(left.writes == [0x0F])
    }

    @Test("rotation is held after a change")
    func rotationHeld() async {
        desk.add("Left", pinnedRotation: 90)
        await reconnect(added: false)
        #expect(desk.display("Left").rotation == 90)
    }

    @Test("the display callback reaches the controller once it has started")
    func callback() async {
        let left = desk.add("Left")
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        left.input = 0x11
        controller.start()
        desk.displays.fireReconfigure(added: true)
        await settle("reconnect to run") { left.input == 0x0F }
    }
}

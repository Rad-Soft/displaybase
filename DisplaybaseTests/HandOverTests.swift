//
//  HandOverTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct HandOverTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    @Test("one screen goes over and the menu bar lands on the one that stays")
    func oneScreen() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")

        #expect(controller.mode == .pc && !controller.busy && controller.note == nil)
        #expect(left.input == 0x11)
        #expect(!desk.display("Left").active && desk.display("Right").active)
        #expect(desk.displays.main?.monitor.name == "Right")
        let away = desk.prefs.handover?.away
        #expect(away?.count == 1 && away?[0].monitor == desk.id("Left"))
        #expect(away?[0].display == desk.display("Left").id)
        #expect(away?[0].macInput == 0x0F)
        #expect(desk.screen("Left")?.macInput == 0x0F)
        #expect(desk.log.contains("windows restore Right"))
        #expect(!desk.displays.lostEveryScreen)
    }

    @Test("several screens go together and only the ones that stay get their windows back")
    func severalScreens() async {
        let left = desk.add("Left", role: .goes)
        let middle = desk.add("Middle", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")

        #expect(controller.mode == .pc)
        #expect(left.input == 0x11 && middle.input == 0x11)
        #expect(!desk.display("Left").active && !desk.display("Middle").active)
        #expect(desk.prefs.handover?.away.map(\.monitor.name) == ["Left", "Middle"])
        #expect(desk.log.contains("windows restore Right"))
        #expect(!desk.log.contains("windows restore Left") && !desk.log.contains("windows restore Middle"))
        #expect(desk.displays.main?.monitor.name == "Right")
    }

    @Test("a screen with its own hand-over input uses it")
    func ownInput() async {
        let left = desk.add("Left", role: .goes, input: 0x0F, pcInput: 0x12)
        desk.add("Right")
        await controller.handOver("shortcut")
        #expect(left.input == 0x12)
    }

    @Test("the layout is captured before anything changes, and the screen goes off before the menu bar moves")
    func order() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")

        #expect(desk.log.happened("snapshot", before: "ddc Left 0x11"))
        #expect(desk.log.happened("windows capture", before: "ddc Left 0x11"))
        #expect(desk.log.happened("ddc Left 0x11", before: "disable Left"))
        #expect(desk.log.happened("disable Left", before: "main Right"))
        #expect(desk.log.happened("main Right", before: "windows restore Right"))
        let saved = desk.prefs.handover?.layout?.placements
        #expect(saved?.map(\.monitor.name) == ["Left", "Right"])
        #expect(saved?[0].x == 0 && saved?[1].x == 2560)
    }

    @Test("what's needed to come back is saved before the screen is turned off")
    func savedBeforeTurningOff() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        var saved: Handover?
        desk.log.onEvent = { [desk] event in
            if event == "disable Left" { saved = Preferences(defaults: desk.defaults).handover }
        }
        await controller.handOver("shortcut")
        #expect(saved?.has(desk.id("Left")) == true)
        #expect(saved?.away[0].display == desk.display("Left").id)
        #expect(saved?.away[0].macInput == 0x0F)
        #expect(saved?.layout?.placements.count == 2)
    }

    @Test("the menu bar stays put when the screen that stays already has it")
    func menuBarAlreadyThere() async {
        desk.add("Left", role: .goes, x: 2560)
        desk.add("Right", x: 0)
        await controller.handOver("shortcut")
        #expect(!desk.log.contains("main Right"))
        #expect(desk.displays.main?.monitor.name == "Right")
    }

    @Test("a laptop screen can be what the Mac keeps")
    func laptopStays() async {
        desk.add("Left", role: .goes)
        desk.addLaptop()
        await controller.handOver("shortcut")
        #expect(controller.mode == .pc)
        #expect(desk.displays.main?.isBuiltin == true)
        #expect(!desk.displays.lostEveryScreen)
    }

    @Test("the keyboard being on the other computer is remembered")
    func keyboardPlace() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        controller.switchSpot = .pc
        await controller.handOver("switch moved")
        #expect(desk.prefs.handover?.keyboardOnPC == true)
    }

    @Test("a monitor that answers nothing can't be switched, so nothing happens")
    func silentMonitor() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        left.answersReads = false
        await controller.handOver("shortcut")
        #expect(controller.mode == .mac && desk.prefs.handover == nil)
        #expect(controller.note == "Left didn't switch to PC.")
        #expect(desk.display("Left").active)
    }

    @Test("the note uses the other computer's name")
    func namedComputer() async {
        desk.add("Left", role: .goes).refusesSwitch = true
        desk.add("Right")
        desk.prefs.pcName = "Gaming Rig"
        await controller.handOver("shortcut")
        #expect(controller.note == "Left didn't switch to Gaming Rig.")
        desk.prefs.pcName = ""
        await controller.handOver("shortcut")
        #expect(controller.note == "Left didn't switch to the other computer.")
    }

    @Test("nothing to do while busy or already over there")
    func guards() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        controller.busy = true
        await controller.handOver("shortcut")
        controller.busy = false
        controller.mode = .pc
        await controller.handOver("shortcut")
        #expect(desk.log.events.isEmpty && controller.note == nil)
    }

    @Test("a screen that goes is only marked once, even asked twice")
    func twice() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        await controller.handOver("shortcut")
        #expect(desk.prefs.handover?.away.count == 1)
        #expect(desk.log.count(of: "disable Left") == 1)
    }
}

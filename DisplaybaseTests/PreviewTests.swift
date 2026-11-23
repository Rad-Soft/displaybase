//
//  PreviewTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct PreviewTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    @Test("a preview shows the other computer for a few seconds and comes back by itself")
    func returns() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        let screen = desk.screen("Left")!
        await controller.preview(screen)

        #expect(left.input == 0x0F && controller.note == nil && !controller.busy)
        #expect(left.writes == [0x11, 0x0F])
        #expect(desk.clock.sleeps.contains(.seconds(5)))
        #expect(desk.log.happened("ddc Left 0x11", before: "ddc Left 0xf"))
        #expect(!desk.log.contains("disable Left"))
    }

    @Test("what the monitor was on is what the Mac's input becomes, when it was different")
    func learnsInput() async {
        let left = desk.add("Left", role: .goes, input: 0x12)
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        await controller.preview(desk.screen("Left")!)
        #expect(left.input == 0x12 && desk.screen("Left")?.macInput == 0x12)
    }

    @Test("the other computer's input is never saved as the Mac's")
    func neverSavesPCInput() async {
        let left = desk.add("Left", role: .goes)
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        // the monitor happens to be showing the other computer right now
        left.input = 0x11
        await controller.preview(desk.screen("Left")!)
        #expect(desk.screen("Left")?.macInput == 0x0F)
        #expect(left.input == 0x11)
    }

    @Test("a monitor that doesn't answer says to turn on DDC/CI and isn't touched")
    func silent() async {
        let left = desk.add("Left", role: .goes)
        left.answersReads = false
        await controller.preview(desk.screen("Left")!)
        #expect(controller.note == "Left doesn't answer. Turn on DDC/CI in the monitor's own menu.")
        #expect(left.writes.isEmpty && !controller.busy)
    }

    @Test("a monitor that won't come back asks for the button")
    func wontReturn() async {
        let left = desk.add("Left", role: .goes)
        // switches over fine, then refuses to switch back
        left.refusesAfter = 1
        await controller.preview(desk.screen("Left")!)
        #expect(controller.note == "Left didn't come back. Use the input button on the monitor.")
        #expect(left.input == 0x11 && !controller.busy)
        #expect(left.writes.filter { $0 == 0x0F }.count == 6)
    }

    @Test("only the Mac can preview, and only one thing at a time")
    func guards() async {
        let left = desk.add("Left", role: .goes)
        let screen = desk.screen("Left")!
        controller.busy = true
        await controller.preview(screen)
        controller.busy = false
        controller.mode = .pc
        await controller.preview(screen)
        #expect(left.writes.isEmpty && desk.log.events.isEmpty)
    }

    @Test("a note from before is cleared once a preview starts")
    func clearsNote() async {
        desk.add("Left", role: .goes)
        controller.note = "old"
        await controller.preview(desk.screen("Left")!)
        #expect(controller.note == nil)
    }
}

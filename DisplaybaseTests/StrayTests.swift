//
//  StrayTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct StrayTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    /// Left has been handed over and then refuses to come back.
    func strandedLeft() async -> FakeMonitor {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        left.refusesSwitch = true
        await controller.takeBack("shortcut")
        desk.log.clear()
        return left
    }

    @Test("a screen that won't come back becomes a stray and the Mac carries on")
    func becomesStray() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        left.refusesSwitch = true
        await controller.takeBack("shortcut")

        #expect(controller.note == "Left didn't switch back. Use the input button on the monitor.")
        #expect(controller.strays[desk.id("Left")] == 8)
        #expect(controller.mode == .mac && desk.prefs.handover == nil && !controller.busy)
        #expect(desk.display("Left").active)
        #expect(left.writes.filter { $0 == 0x0F }.count == 6)
    }

    @Test("strays are retried once a time and eventually given up on")
    func givesUp() async {
        let left = await strandedLeft()
        let writesBefore = left.writes.count

        for round in 1...8 {
            await controller.fetchStrays()
            #expect(controller.strays[desk.id("Left")] == 8 - round)
        }
        #expect(left.writes.count == writesBefore + 8)

        await controller.fetchStrays()
        #expect(controller.strays.isEmpty)
        #expect(left.writes.count == writesBefore + 8)
        await controller.fetchStrays()
        #expect(left.writes.count == writesBefore + 8)
    }

    @Test("a stray that finally answers is brought back and the note clears")
    func recovers() async {
        let left = await strandedLeft()
        await controller.fetchStrays()
        await controller.fetchStrays()
        #expect(controller.strays[desk.id("Left")] == 6)
        left.refusesSwitch = false
        await controller.fetchStrays()
        #expect(controller.strays.isEmpty && controller.note == nil)
        #expect(left.input == 0x0F)
    }

    @Test("strays are left alone while the Mac isn't in charge, or busy")
    func notNow() async {
        let left = await strandedLeft()
        let writes = left.writes.count
        controller.busy = true
        await controller.fetchStrays()
        controller.busy = false
        controller.mode = .pc
        await controller.fetchStrays()
        #expect(left.writes.count == writes && controller.strays[desk.id("Left")] == 8)
    }

    @Test("a stray whose Mac input was never learned is dropped, not guessed at")
    func unknownInput() async {
        _ = await strandedLeft()
        desk.prefs.update(desk.id("Left")) { $0.macInput = nil }
        await controller.fetchStrays()
        #expect(controller.strays.isEmpty)
    }

    @Test("a new hand-over forgets old strays")
    func clearedByHandOver() async {
        _ = await strandedLeft()
        desk.monitor("Left").refusesSwitch = false
        await controller.handOver("shortcut")
        #expect(controller.strays.isEmpty)
    }

    @Test("polling brings strays back on its own")
    func polling() async {
        let left = await strandedLeft()
        left.refusesSwitch = false
        _ = await controller.pollOnce()
        #expect(left.input == 0x0F && controller.strays.isEmpty)
    }
}

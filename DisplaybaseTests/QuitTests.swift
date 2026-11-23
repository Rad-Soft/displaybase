//
//  QuitTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct QuitTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    @Test("quitting in the middle of a hand-over lets it finish, then brings everything home")
    func quitDuringHandOver() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        let handOver = Task { await controller.handOver("shortcut") }
        await settle("hand-over to start") { controller.busy }

        await controller.comeHome("quit")
        await handOver.value

        #expect(controller.mode == .mac && !controller.busy && desk.prefs.handover == nil)
        #expect(left.input == 0x0F && desk.display("Left").active)
        #expect(desk.log.count(of: "ddc Left 0x11") == 1)
        #expect(desk.log.count(of: "restore layout") == 1)
        #expect(desk.log.happened("disable Left", before: "enable Left"))
        #expect(desk.log.happened("windows restore Right", before: "enable Left"))
    }

    @Test("updating in the middle of a hand-over does the same, whatever started it")
    func updateDuringHandOver() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        let handOver = Task { await controller.handOver("shortcut") }
        await settle("hand-over to start") { controller.busy }

        let update = Task { await controller.comeHome("updating") }
        update.cancel()
        await update.value
        await handOver.value
        #expect(controller.mode == .mac && left.input == 0x0F && desk.display("Left").active)
        #expect(desk.prefs.handover == nil)
    }

    @Test("quitting in the middle of a take-back doesn't take back twice")
    func quitDuringTakeBack() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        desk.log.clear()

        let takeBack = Task { await controller.takeBack("shortcut") }
        await settle("take-back to start") { controller.busy }
        await controller.comeHome("quit")
        await takeBack.value

        #expect(controller.mode == .mac && left.input == 0x0F && desk.prefs.handover == nil)
        #expect(desk.log.count(of: "enable Left") == 1)
        #expect(desk.log.count(of: "restore layout") == 1)
    }

    @Test("quitting with everything already home does nothing")
    func nothingToDo() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.comeHome("quit")
        #expect(desk.log.events.isEmpty && controller.mode == .mac)
    }

    @Test("quitting after a hand-over that never took leaves nothing to undo")
    func failedHandOver() async {
        desk.add("Left", role: .goes).refusesSwitch = true
        desk.add("Right")
        let handOver = Task { await controller.handOver("shortcut") }
        await settle("hand-over to start") { controller.busy }
        await controller.comeHome("quit")
        await handOver.value
        #expect(controller.mode == .mac && !desk.log.contains("restore layout"))
        #expect(!desk.log.contains("enable Left"))
    }

    @Test("it gives up waiting for something stuck, and doesn't touch the screens")
    func stuck() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        desk.log.clear()
        controller.busy = true
        await controller.comeHome("quit")
        #expect(controller.mode == .pc && desk.log.events.isEmpty)
        #expect(desk.clock.elapsed >= .seconds(60))
    }
}

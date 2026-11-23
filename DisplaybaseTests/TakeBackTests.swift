//
//  TakeBackTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct TakeBackTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    /// Left (main, goes) and Right, handed over.
    func handedOver() async -> (left: FakeMonitor, right: FakeMonitor) {
        let left = desk.add("Left", role: .goes)
        let right = desk.add("Right")
        await controller.handOver("shortcut")
        desk.log.clear()
        return (left, right)
    }

    @Test("taking back restores inputs, layout and windows, in that order")
    func restoresEverything() async {
        let (left, _) = await handedOver()
        await controller.takeBack("shortcut")

        #expect(controller.mode == .mac && !controller.busy && controller.note == nil)
        #expect(left.input == 0x0F && desk.display("Left").active)
        #expect(desk.prefs.handover == nil && Preferences(defaults: desk.defaults).handover == nil)
        #expect(desk.displays.main?.monitor.name == "Left")
        #expect(desk.display("Right").frame.origin == CGPoint(x: 2560, y: 0))
        #expect(desk.log.happened("enable Left", before: "ddc Left 0xf"))
        #expect(desk.log.happened("ddc Left 0xf", before: "restore layout"))
        #expect(desk.log.happened("restore layout", before: "windows restore all"))
        #expect(desk.log.happened("windows restore all", before: "windows forget"))
        #expect(desk.log.contains("lent windows forget"))
        #expect(controller.layout.placements.map(\.monitor.name) == ["Left", "Right"])
    }

    @Test("it goes back to the input the screen was on when it left, not what settings say now")
    func rememberedInput() async {
        let (left, _) = await handedOver()
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x10 }
        await controller.takeBack("shortcut")
        #expect(left.input == 0x0F)
    }

    @Test("settings fill in when the saved hand-over doesn't know the input")
    func fallbackInput() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        left.input = 0x11
        desk.display("Left").active = false
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        desk.prefs.handover = Handover(away: [.init(monitor: desk.id("Left"), display: desk.display("Left").id)], layout: nil)
        await controller.takeBack("relaunch")
        #expect(left.input == 0x0F && desk.display("Left").active && controller.mode == .mac)
        #expect(!desk.log.contains("restore layout"))
    }

    @Test("a screen that stayed but wandered to the other input is brought back too")
    func wanderer() async {
        let (_, right) = await handedOver()
        right.input = 0x11
        await controller.takeBack("shortcut")
        #expect(right.input == 0x0F)
        #expect(desk.log.contains("ddc Right 0xf"))
    }

    @Test("one that stayed where it belongs is left alone")
    func steady() async {
        _ = await handedOver()
        await controller.takeBack("shortcut")
        #expect(!desk.log.events.contains { $0.hasPrefix("ddc Right") })
    }

    @Test("a screen that comes back slowly is waited for")
    func slowToReturn() async {
        _ = await handedOver()
        desk.display("Left").slowChecks = 3
        await controller.takeBack("shortcut")
        #expect(desk.clock.sleeps.filter { $0 == .milliseconds(250) }.count == 3)
        #expect(desk.monitor("Left").input == 0x0F)
    }

    @Test("and not for more than five seconds")
    func neverActive() async {
        _ = await handedOver()
        desk.display("Left").slowChecks = 1000
        await controller.takeBack("shortcut")
        #expect(desk.clock.sleeps.filter { $0 == .milliseconds(250) }.count == 20)
        #expect(controller.mode == .mac)
    }

    @Test("nothing happens when the Mac already has everything, or while busy")
    func guards() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.takeBack("shortcut")
        #expect(desk.log.events.isEmpty)

        await controller.handOver("shortcut")
        desk.log.clear()
        controller.busy = true
        await controller.takeBack("shortcut")
        #expect(desk.log.events.isEmpty && controller.mode == .pc)
    }

    @Test("a layout is only restored when there was one")
    func noLayout() async {
        let left = desk.add("Left", role: .goes)
        desk.display("Left").active = false
        left.input = 0x11
        desk.prefs.update(desk.id("Left")) { $0.macInput = 0x0F }
        desk.prefs.handover = Handover(away: [.init(monitor: desk.id("Left"), display: desk.display("Left").id)], layout: nil)
        await controller.takeBack("shortcut")
        #expect(desk.prefs.handover == nil && !desk.log.contains("restore layout"))
    }

    @Test("taking back does the same for several screens")
    func several() async {
        let left = desk.add("Left", role: .goes)
        let middle = desk.add("Middle", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        await controller.takeBack("shortcut")
        #expect(left.input == 0x0F && middle.input == 0x0F)
        #expect(desk.display("Left").active && desk.display("Middle").active)
        #expect(controller.mode == .mac && controller.strays.isEmpty)
        #expect(desk.displays.main?.monitor.name == "Left")
    }

    @Test("doing it over and over leaves the desk exactly as it was")
    func repeatable() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        desk.addLaptop()
        let frames = desk.displays.all.map(\.frame)
        for _ in 0..<3 {
            await controller.handOver("shortcut")
            #expect(controller.mode == .pc)
            await controller.takeBack("shortcut")
        }
        #expect(desk.displays.all.map(\.frame) == frames)
        #expect(desk.displays.all.allSatisfy(\.active) && left.input == 0x0F)
        #expect(!desk.displays.lostEveryScreen)
    }

    @Test("the desk map says which screens are over there")
    func deskMap() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await controller.handOver("shortcut")
        let items = controller.desk
        #expect(items.map(\.onPC) == [true, false])
        #expect(items[0] == controller.desk[0] && items[0] != items[1])
        #expect(items[0].id == desk.id("Left"))
    }
}

//
//  RelaunchTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct RelaunchTests {
    let desk = SimulatedDesk()

    @Test("relaunching in the middle of a hand-over picks up in the other computer's mode")
    func picksUp() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        await desk.controller.handOver("shortcut")

        let again = desk.relaunch()
        #expect(again.mode == .pc)
        #expect(again.desk.map(\.onPC) == [true, false])
        await again.takeBack("shortcut")

        #expect(again.mode == .mac && left.input == 0x0F && desk.display("Left").active)
        #expect(desk.prefs.handover == nil)
        #expect(desk.display("Right").frame.origin == CGPoint(x: 2560, y: 0))
    }

    @Test("a launch with nothing away starts with the Mac in charge")
    func freshLaunch() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        #expect(desk.relaunch().mode == .mac)
    }

    @Test("a relaunch that hands over again can't be confused by the old state")
    func handOverAfterRelaunch() async {
        desk.add("Left", role: .goes)
        desk.add("Right")
        await desk.controller.handOver("shortcut")
        await desk.controller.takeBack("shortcut")
        let again = desk.relaunch()
        await again.handOver("shortcut")
        #expect(again.mode == .pc && desk.prefs.handover?.away.count == 1)
    }

    @Test("what was saved when the screen turned off is enough to come back from a crash")
    func crashAtTheWrongMoment() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        var saved: Preferences?
        desk.log.onEvent = { [desk] event in
            if event == "disable Left" { saved = Preferences(defaults: desk.defaults) }
        }
        await desk.controller.handOver("shortcut")

        // the app died right there: the screen is off and the monitor is on the other input
        desk.display("Left").active = false
        left.input = 0x11
        desk.relaunch()
        let again = desk.controller
        #expect(saved?.handover?.away.first?.macInput == 0x0F)
        #expect(saved?.handover?.layout?.placements.count == 2)
        await again.takeBack("shortcut")
        #expect(left.input == 0x0F && desk.display("Left").active && again.mode == .mac)
    }

    @Test("a relaunch with a screen that's still on and away is just as recoverable")
    func stillOn() async {
        let left = desk.add("Left", role: .goes)
        desk.add("Right")
        desk.display("Left").refusesDisable = true
        await desk.controller.handOver("shortcut")
        let again = desk.relaunch()
        await again.takeBack("shortcut")
        #expect(left.input == 0x0F && again.mode == .mac)
    }
}

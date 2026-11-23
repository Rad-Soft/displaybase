//
//  UpgradeTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct UpgradeTests {
    let monitor = #"{"vendor":1,"model":2,"serial":3,"name":"Main"}"#

    @Test("a screen saved with only a monitor still loads")
    func screen() throws {
        let screen = try JSONDecoder().decode(DeskScreen.self, from: Data(#"{"monitor":\#(monitor)}"#.utf8))
        #expect(screen.role == .stays && screen.pcInput == 0x0F && screen.macInput == nil && screen.rotation == nil)
    }

    @Test("a handover saved by an older version still knows what's away")
    func handover() throws {
        let json = #"{"away":[{"monitor":\#(monitor),"display":4}]}"#
        let handover = try JSONDecoder().decode(Handover.self, from: Data(json.utf8))
        #expect(handover.away.count == 1 && handover.away[0].display == 4)
        #expect(!handover.away[0].optional && handover.away[0].macInput == nil && !handover.keyboardOnPC)
    }

    @Test func linksAreOffUntilAllowed() {
        let name = "displaybase.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(!Preferences(defaults: defaults).allowLinks)
    }

    @Test("waits for a hand-over to finish before moving on")
    func waitsForIdle() async {
        let desk = SimulatedDesk()
        let controller = desk.controller
        controller.busy = true
        Task {
            await settle("a few waits") { desk.clock.sleeps.count >= 3 }
            controller.busy = false
        }
        await controller.whenIdle()
        #expect(!controller.busy)
        #expect(desk.clock.sleeps.allSatisfy { $0 == .milliseconds(200) })
    }

    @Test("gives up waiting after a minute")
    func givesUpWaiting() async {
        let desk = SimulatedDesk()
        desk.controller.busy = true
        await desk.controller.whenIdle()
        #expect(desk.controller.busy)
        #expect(desk.clock.elapsed >= .seconds(60) && desk.clock.elapsed < .seconds(61))
    }

    @Test("canceling whatever started it doesn't stop it half way")
    func uninterrupted() async {
        let desk = SimulatedDesk()
        var finished = false
        let task = Task {
            await desk.controller.uninterrupted {
                await desk.clock.sleep(for: .milliseconds(200))
                await desk.clock.sleep(for: .milliseconds(200))
                finished = true
            }
        }
        task.cancel()
        await task.value
        #expect(finished)
    }
}

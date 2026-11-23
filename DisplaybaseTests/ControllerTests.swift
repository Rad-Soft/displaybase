//
//  ControllerTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct ControllerTests {
    let main = MonitorID(vendor: 1, model: 1, serial: 1, name: "Main")
    let side = MonitorID(vendor: 1, model: 2, serial: 1, name: "Side")

    func preferences() -> Preferences {
        let name = "displaybase.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return Preferences(defaults: defaults)
    }

    func placement(_ monitor: MonitorID, x: Int32 = 0, y: Int32 = 0, builtin: Bool = false) -> LayoutSnapshot.Placement {
        .init(monitor: monitor, x: x, y: y, rotation: 0, width: 100, height: 50, isBuiltin: builtin)
    }

    @Test func deskPrefersTheHandoverLayout() {
        let prefs = preferences()
        let controller = SimulatedDesk(prefs: prefs).controller
        controller.layout = LayoutSnapshot(placements: [placement(side, x: 7)])
        #expect(controller.desk.map(\.monitor) == [side])
        #expect(controller.desk[0].onPC == false)

        prefs.handover = Handover(away: [.init(monitor: main)], layout: LayoutSnapshot(placements: [placement(main, x: -3, y: -4, builtin: true)]))
        let item = controller.desk[0]
        #expect(item.monitor == main && item.onPC && item.isBuiltin)
        #expect(item.frame == CGRect(x: -3, y: -4, width: 100, height: 50))
    }

    @Test func deskFallsBackToLiveLayoutWithoutASnapshot() {
        let prefs = preferences()
        prefs.handover = Handover(away: [.init(monitor: main)], layout: nil)
        let controller = SimulatedDesk(prefs: prefs).controller
        controller.layout = LayoutSnapshot(placements: [placement(main), placement(side, x: 100)])
        #expect(controller.desk.map(\.onPC) == [true, false])
    }

    @Test func emptyDesk() {
        #expect(SimulatedDesk(prefs: preferences()).controller.desk.isEmpty)
    }

    @Test func everyScreenAway() {
        let prefs = preferences()
        let controller = SimulatedDesk(prefs: prefs).controller
        #expect(!controller.everyScreenAway)
        prefs.handover = Handover(away: [.init(monitor: main)], layout: nil)
        #expect(!controller.everyScreenAway)
        prefs.handover?.away.append(.init(monitor: side, optional: true))
        #expect(controller.everyScreenAway)
    }

    @Test("the menu bar prefers optional, then staying, then external, then anything")
    func homeOrder() {
        let prefs = preferences()
        let laptop = MonitorID(vendor: 9, model: 9, serial: 9, name: "Laptop")
        let other = MonitorID(vendor: 8, model: 8, serial: 8, name: "Other")
        prefs.screens = [DeskScreen(monitor: main, role: .goes), DeskScreen(monitor: side, role: .stays)]
        let controller = SimulatedDesk(prefs: prefs).controller
        let builtin = ScreenInfo(id: 1, monitor: laptop, isBuiltin: true)
        let external = ScreenInfo(id: 2, monitor: other, isBuiltin: false)
        let going = ScreenInfo(id: 3, monitor: main, isBuiltin: false)
        let staying = ScreenInfo(id: 4, monitor: side, isBuiltin: false)

        #expect(controller.homeScreen(among: [builtin, going, staying])?.monitor == side)
        #expect(controller.homeScreen(among: [builtin, external])?.monitor == other)
        #expect(controller.homeScreen(among: [builtin])?.monitor == laptop)
        #expect(controller.homeScreen(among: [])?.monitor == nil)
    }

    @Test("handing over without a screen set to go says what to do")
    func nothingToHandOver() async {
        let prefs = preferences()
        prefs.screens = [DeskScreen(monitor: main, role: .stays), DeskScreen(monitor: side, role: .optional)]
        let controller = SimulatedDesk(prefs: prefs).controller
        await controller.handOver("test")
        #expect(controller.note == "Pick a screen to share in Settings.")
        #expect(controller.mode == .mac && !controller.busy && prefs.handover == nil)
    }

    @Test func nothingToHandOverWithNoScreensAtAll() async {
        let controller = SimulatedDesk(prefs: preferences()).controller
        await controller.handOver("test")
        #expect(controller.note == "Pick a screen to share in Settings.")
    }

    @Test func handOverDoesNothingWhileBusyOrAway() async {
        let controller = SimulatedDesk(prefs: preferences()).controller
        controller.busy = true
        await controller.handOver("test")
        #expect(controller.note == nil)
        controller.busy = false
        controller.mode = .pc
        await controller.handOver("test")
        #expect(controller.note == nil)
    }
}

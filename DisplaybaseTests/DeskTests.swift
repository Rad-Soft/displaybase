//
//  DeskTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct DeskTests {
    let main = MonitorID(vendor: 1, model: 1, serial: 1, name: "Main")
    let side = MonitorID(vendor: 1, model: 2, serial: 1, name: "Side")

    func preferences() -> Preferences {
        let name = "displaybase.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return Preferences(defaults: defaults)
    }

    @Test func fitsTheDesk() {
        let frames = [CGRect(x: 0, y: -1080, width: 1920, height: 1080), CGRect(x: -1080, y: -1080, width: 1080, height: 1920)]
        let fitted = DeskLayout.fit(frames, in: CGSize(width: 300, height: 100))
        let box = fitted[0].union(fitted[1])
        #expect(box.minX >= 0 && box.minY >= 0 && box.maxX <= 300.001 && box.maxY <= 100.001)
        #expect(abs(fitted[0].width / fitted[0].height - 1920.0 / 1080.0) < 0.001)
        #expect(abs(fitted[1].maxX - fitted[0].minX) < 0.001)
        #expect(DeskLayout.fit([], in: CGSize(width: 10, height: 10)).isEmpty)
    }

    @Test func startsEmpty() {
        let prefs = preferences()
        #expect(prefs.screens.isEmpty && prefs.switchDevice == nil && !prefs.hasRemote && !prefs.setupDone)
        #expect(prefs.shortcut == .standard)
    }

    @Test func remembersSettings() {
        let name = "displaybase.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let prefs = Preferences(defaults: defaults)
        prefs.screens = [DeskScreen(monitor: main, role: .goes, pcInput: 0x11, macInput: 0x1B), DeskScreen(monitor: side, role: .optional, rotation: 270)]
        prefs.handover = Handover(away: [.init(monitor: main, display: 4)], layout: nil)

        let again = Preferences(defaults: defaults)
        #expect(again.screens == prefs.screens)
        #expect(again.handover?.has(main) == true)
        #expect(again.handover?.has(side) == false)
        #expect(again.hasOptional)
    }

    @Test("a relaunch mid-handover picks up where it left off")
    func relaunch() {
        let prefs = preferences()
        #expect(SimulatedDesk(prefs: prefs).controller.mode == .mac)
        prefs.handover = Handover(away: [.init(monitor: main)], layout: nil)
        #expect(SimulatedDesk(prefs: prefs).controller.mode == .pc)
    }

    @Test func mapShowsWhoHasWhat() {
        let prefs = preferences()
        let layout = LayoutSnapshot(placements: [
            .init(monitor: main, x: 0, y: 0, rotation: 0, width: 2560, height: 1440, isBuiltin: false),
            .init(monitor: side, x: -1440, y: 0, rotation: 270, width: 1440, height: 2560, isBuiltin: false),
        ])
        prefs.handover = Handover(away: [.init(monitor: main)], layout: layout)
        let desk = SimulatedDesk(prefs: prefs).controller.desk
        #expect(desk.map(\.onPC) == [true, false])
        #expect(desk[1].frame.minX == -1440)
    }

    @Test("the menu bar lands on an optional screen before one that stays")
    func home() {
        let prefs = preferences()
        let laptop = MonitorID(vendor: 9, model: 9, serial: 9, name: "Laptop")
        prefs.screens = [DeskScreen(monitor: main, role: .stays), DeskScreen(monitor: side, role: .optional)]
        let controller = SimulatedDesk(prefs: prefs).controller
        let screens = [
            ScreenInfo(id: 1, monitor: laptop, isBuiltin: true),
            ScreenInfo(id: 2, monitor: main, isBuiltin: false),
            ScreenInfo(id: 3, monitor: side, isBuiltin: false),
        ]
        #expect(controller.homeScreen(among: screens)?.monitor == side)
        #expect(controller.homeScreen(among: [screens[0], screens[1]])?.monitor == main)
        #expect(controller.homeScreen(among: [screens[0]])?.monitor == laptop)
        #expect(controller.homeScreen(among: []) == nil)
    }

    @Test func shortcutLabel() {
        #expect(Shortcut.standard.label == "⌃⌥⌘D")
    }
}

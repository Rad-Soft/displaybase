//
//  FindScreensTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct FindScreensTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    @Test("monitors it hasn't seen are added with the other input to go to")
    func addsMonitors() async {
        desk.addUnconfigured("On DisplayPort", input: 0x0F)
        desk.addUnconfigured("On HDMI", input: 0x11)
        await controller.findScreens()
        #expect(desk.prefs.screens.count == 2)
        #expect(desk.screen("On DisplayPort")?.pcInput == 0x11 && desk.screen("On DisplayPort")?.macInput == 0x0F)
        #expect(desk.screen("On HDMI")?.pcInput == 0x0F && desk.screen("On HDMI")?.macInput == 0x11)
    }

    @Test("a monitor that won't say its input still gets added")
    func silentMonitor() async {
        desk.addUnconfigured("Quiet", input: nil)
        await controller.findScreens()
        #expect(desk.screen("Quiet")?.macInput == nil && desk.screen("Quiet")?.pcInput == 0x0F)
    }

    @Test("a rotated screen remembers its rotation, an upright one leaves it to macOS")
    func rotation() async {
        desk.addUnconfigured("Tall", rotated: 90)
        desk.addUnconfigured("Flat")
        await controller.findScreens()
        #expect(desk.screen("Tall")?.rotation == 90 && desk.screen("Flat")?.rotation == nil)
    }

    @Test("the first time, the biggest landscape screen is the one to share")
    func sharesTheBiggest() async {
        desk.addUnconfigured("Small", size: CGSize(width: 1920, height: 1080))
        desk.addUnconfigured("Big", size: CGSize(width: 3840, height: 2160))
        await controller.findScreens()
        #expect(desk.prefs.screens.map(\.role) == [.stays, .goes])
    }

    @Test("landscape counts double, so a portrait screen of the same size doesn't win")
    func landscapeWins() async {
        desk.addUnconfigured("Portrait", size: CGSize(width: 1440, height: 2560))
        desk.addUnconfigured("Landscape", size: CGSize(width: 2560, height: 1440))
        await controller.findScreens()
        #expect(desk.screen("Landscape")?.role == .goes && desk.screen("Portrait")?.role == .stays)
    }

    @Test("but a much bigger portrait screen still does")
    func muchBiggerPortrait() async {
        desk.addUnconfigured("Portrait", size: CGSize(width: 3000, height: 4000))
        desk.addUnconfigured("Landscape", size: CGSize(width: 2560, height: 1440))
        await controller.findScreens()
        #expect(desk.screen("Portrait")?.role == .goes)
    }

    @Test("later, new monitors are added but nobody's role changes")
    func later() async {
        desk.add("Known", role: .optional)
        desk.addUnconfigured("New")
        await controller.findScreens()
        #expect(desk.screen("New")?.role == .stays && desk.screen("Known")?.role == .optional)
        #expect(desk.prefs.screens.count == 2)
    }

    @Test("monitors already known aren't added again")
    func noDuplicates() async {
        desk.add("Known")
        await controller.findScreens()
        await controller.findScreens()
        #expect(desk.prefs.screens.count == 1)
        #expect(desk.monitor("Known").writes.isEmpty)
    }

    @Test("it reads the layout too")
    func readsLayout() async {
        desk.add("Known")
        await controller.findScreens()
        #expect(controller.layout.placements.map(\.monitor.name) == ["Known"])
    }

    @Test("with nothing connected there's nothing to share")
    func empty() async {
        await controller.findScreens()
        #expect(desk.prefs.screens.isEmpty)
    }
}

//
//  RotationTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct RotationTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    @Test("a pinned rotation that macOS dropped is put back")
    func putsBack() {
        desk.add("Left", pinnedRotation: 90, rotated: 0)
        #expect(controller.holdRotation())
        #expect(desk.display("Left").rotation == 90)
        #expect(desk.log.contains("rotate Left 90"))
    }

    @Test("one that's already right isn't touched")
    func alreadyRight() {
        desk.add("Left", pinnedRotation: 270, rotated: 270)
        #expect(!controller.holdRotation())
        #expect(desk.log.events.isEmpty)
    }

    @Test("a screen with nothing pinned is left to macOS")
    func notPinned() {
        desk.add("Left", rotated: 180)
        #expect(!controller.holdRotation())
        #expect(desk.display("Left").rotation == 180)
    }

    @Test("a screen that can't be rotated doesn't count as turned")
    func cannotRotate() {
        desk.add("Left", pinnedRotation: 90)
        desk.display("Left").cannotRotate = true
        #expect(!controller.holdRotation())
        #expect(desk.display("Left").rotation == 0)
    }

    @Test("a screen that isn't connected is skipped")
    func notConnected() {
        desk.add("Left", pinnedRotation: 90)
        desk.display("Left").active = false
        #expect(!controller.holdRotation())
        #expect(desk.log.events.isEmpty)
    }

    @Test("rotation survives a hand-over and a take-back, even when macOS resets it each time")
    func surviveHandOver() async {
        desk.add("Left", role: .goes, pinnedRotation: 90, rotated: 90)
        desk.add("Right", pinnedRotation: 270, rotated: 270)
        desk.display("Left").resetsRotation = true
        desk.display("Right").resetsRotation = true

        await controller.handOver("shortcut")
        #expect(desk.display("Right").rotation == 270)
        #expect(desk.log.contains("rotate Right 270"))
        #expect(desk.clock.elapsed >= .seconds(3))

        desk.log.clear()
        await controller.takeBack("shortcut")
        #expect(desk.display("Right").rotation == 270 && desk.display("Left").rotation == 90)
        #expect(desk.clock.elapsed >= .seconds(4))
    }

    @Test("it's put back right when macOS resets it, before waiting out the rest of the time")
    func promptly() async {
        desk.add("Left", pinnedRotation: 90, rotated: 0)
        await controller.settleRotation(for: .seconds(1))
        #expect(desk.log.count(of: "rotate Left 90") == 1)
        #expect(desk.clock.sleeps.first == .milliseconds(500))
        #expect(desk.clock.sleeps.dropFirst().allSatisfy { $0 == .milliseconds(150) })
    }

    @Test("with nothing pinned there's no waiting at all")
    func nothingPinned() async {
        desk.add("Left")
        await controller.settleRotation(for: .seconds(3))
        #expect(desk.clock.sleeps.isEmpty)
    }

    @Test("starting up puts rotation right and reads the layout")
    func startUp() {
        desk.add("Left", pinnedRotation: 90)
        controller.start()
        #expect(desk.display("Left").rotation == 90)
        #expect(controller.layout.placements.map(\.monitor.name) == ["Left"])
    }
}

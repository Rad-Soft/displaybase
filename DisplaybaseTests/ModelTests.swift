//
//  ModelTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

struct ModelTests {
    let main = MonitorID(vendor: 1, model: 1, serial: 1, name: "Main")
    let side = MonitorID(vendor: 1, model: 2, serial: 1, name: "Side")

    func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    @Test func screenDefaults() {
        let screen = DeskScreen(monitor: main)
        #expect(screen.role == .stays)
        #expect(screen.pcInput == 0x0F)
        #expect(screen.macInput == nil && screen.rotation == nil)
        #expect(screen.id == main)
    }

    @Test func screenRoundTrip() throws {
        let full = DeskScreen(monitor: main, role: .goes, pcInput: 0x11, macInput: 0x1B, rotation: 90)
        let bare = DeskScreen(monitor: side)
        #expect(try roundTrip(full) == full)
        let again = try roundTrip(bare)
        #expect(again == bare && again.macInput == nil && again.rotation == nil)
    }

    @Test("roles keep their stored names", arguments: [
        (ScreenRole.stays, "stays"), (.goes, "goes"), (.optional, "optional"),
    ])
    func roles(role: ScreenRole, raw: String) throws {
        #expect(role.rawValue == raw)
        #expect(try roundTrip(role) == role)
        #expect(role.id == role)
    }

    @Test func handoverQueries() {
        var handover = Handover(away: [.init(monitor: main, display: 4)], layout: nil)
        #expect(handover.has(main))
        #expect(!handover.has(side))
        #expect(!handover.keyboardOnPC)
        handover.setDisplay(nil, for: main)
        #expect(handover.away[0].display == nil)
        handover.setDisplay(7, for: main)
        #expect(handover.away[0].display == 7)
    }

    @Test func setDisplayIgnoresStrangers() {
        var handover = Handover(away: [.init(monitor: main, display: 4)], layout: nil)
        handover.setDisplay(9, for: side)
        #expect(handover.away.count == 1 && handover.away[0].display == 4)
    }

    @Test func setDisplayOnlyTouchesItsMonitor() {
        var handover = Handover(away: [.init(monitor: main, display: 1), .init(monitor: side, display: 2)], layout: nil)
        handover.setDisplay(nil, for: side)
        #expect(handover.away.map(\.display) == [1, nil])
    }

    @Test func handoverRoundTrip() throws {
        let layout = LayoutSnapshot(placements: [
            .init(monitor: main, x: -1440, y: -200, rotation: 270, width: 1440, height: 2560, isBuiltin: false),
            .init(monitor: side, x: 0, y: 0, rotation: 0, width: 1512, height: 982, isBuiltin: true),
        ])
        let handover = Handover(
            away: [.init(monitor: main, display: 4, optional: false), .init(monitor: side, optional: true)],
            layout: layout,
            keyboardOnPC: true
        )
        let again = try roundTrip(handover)
        #expect(again.away.map(\.monitor) == [main, side])
        #expect(again.away.map(\.display) == [4, nil])
        #expect(again.away.map(\.optional) == [false, true])
        #expect(again.keyboardOnPC)
        #expect(again.layout?.placements.count == 2)
        #expect(again.layout?.placements[0].x == -1440)
        #expect(again.layout?.placements[0].rotation == 270)
        #expect(again.layout?.placements[1].isBuiltin == true)
    }

    @Test func handoverWithoutOptionalParts() throws {
        let again = try roundTrip(Handover(away: [], layout: nil))
        #expect(again.away.isEmpty && again.layout == nil && !again.keyboardOnPC)
    }

    @Test func layoutRoundTrip() throws {
        let empty = try roundTrip(LayoutSnapshot(placements: []))
        #expect(empty.placements.isEmpty)
        let one = LayoutSnapshot(placements: [.init(monitor: main, x: 5, y: -6, rotation: 90, width: 100, height: 200, isBuiltin: false)])
        let placement = try roundTrip(one).placements[0]
        #expect(placement.monitor == main && placement.x == 5 && placement.y == -6)
        #expect(placement.width == 100 && placement.height == 200 && !placement.isBuiltin)
    }
}

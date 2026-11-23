//
//  MonitorTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Testing

struct MonitorTests {
    @Test("reads the inputs a monitor lists", arguments: [
        ("(prot(monitor)cmds(01 02 03 F3)vcp(02 10 12 14(05 08 0B) 60(0F 11 15) 62)mccs_ver(2.2))", [0x0F, 0x11, 0x15]),
        ("vcp(10 60 ( 01 03 1B ) DF)", [0x01, 0x03, 0x1B]),
        ("vcp(60(11))", [0x11]),
        ("vcp(10 12 160(01 02))", []),
        ("", []),
    ])
    func inputs(capabilities: String, expected: [Int]) {
        #expect(DDC.parseInputs(capabilities) == expected)
    }

    @Test func edid() {
        var edid = [UInt8](repeating: 0, count: 128)
        edid.replaceSubrange(8..<16, with: [0x06, 0xB3, 0x18, 0xAA, 0x01, 0x02, 0x03, 0x04])
        edid.replaceSubrange(72..<90, with: [0, 0, 0, 0xFC, 0] + Array("Desk 32\n     ".utf8))
        let monitor = DDC.monitorID(from: edid)
        #expect(monitor.vendor == 0x06B3)
        #expect(monitor.model == 0xAA18)
        #expect(monitor.serial == 0x0403_0201)
        #expect(monitor.name == "Desk 32")
    }

    @Test func nameDoesNotMatter() {
        let a = MonitorID(vendor: 1, model: 2, serial: 3, name: "A")
        let b = MonitorID(vendor: 1, model: 2, serial: 3, name: "B")
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }
}

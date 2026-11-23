//
//  DDCTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Testing

struct DDCTests {
    @Test("input lists in odd shapes", arguments: [
        ("vcp(60(0f 11 1b))", [0x0F, 0x11, 0x1B]),
        ("VCP(10 60(0F\n11\t15))", [0x0F, 0x11, 0x15]),
        ("vcp(60())", []),
        ("vcp(10 12 14(05 08))", []),
        ("vcp(60(11) 62)", [0x11]),
        ("vcp(60(0F zz 11))", []),
    ])
    func parsing(capabilities: String, expected: [Int]) {
        #expect(DDC.parseInputs(capabilities) == expected)
    }

    @Test func onlyTheFirstListCounts() {
        #expect(DDC.parseInputs("vcp(60(01) 60(02))") == [0x01])
    }

    func edid(name: [UInt8]? = nil, at offset: Int = 72) -> [UInt8] {
        var edid = [UInt8](repeating: 0, count: 128)
        if let name { edid.replaceSubrange(offset..<(offset + 18), with: [0, 0, 0, 0xFC, 0] + name) }
        return edid
    }

    @Test func missingNameFallsBack() {
        #expect(DDC.monitorID(from: edid()).name == "Display")
    }

    @Test("names get trimmed", arguments: [
        ("Desk 32\n", "Desk 32"),
        ("  Desk 32   \n", "Desk 32"),
        ("ProArt PA32UC", "ProArt PA32UC"),
    ])
    func names(raw: String, expected: String) {
        let bytes = Array(raw.utf8) + [UInt8](repeating: 0x20, count: 13 - raw.utf8.count)
        #expect(DDC.monitorID(from: edid(name: bytes)).name == expected)
    }

    @Test("the name can sit in any descriptor slot", arguments: [54, 72, 90, 108])
    func slots(offset: Int) {
        let bytes = Array("Slot\n        ".utf8)
        #expect(DDC.monitorID(from: edid(name: bytes, at: offset)).name == "Slot")
    }

    @Test func idBytes() {
        var data = edid()
        data.replaceSubrange(8..<16, with: [UInt8](repeating: 0xFF, count: 8))
        let monitor = DDC.monitorID(from: data)
        #expect(monitor.vendor == 0xFFFF)
        #expect(monitor.model == 0xFFFF)
        #expect(monitor.serial == UInt32.max)
    }

    @Test("input names", arguments: [
        (0x01, "VGA"), (0x03, "DVI"), (0x04, "DVI 2"), (0x0F, "DisplayPort"), (0x10, "DisplayPort 2"),
        (0x11, "HDMI"), (0x12, "HDMI 2"), (0x15, "Thunderbolt / USB-C"), (0x19, "Thunderbolt / USB-C"),
        (0x1B, "Thunderbolt / USB-C"), (0x2A, "Input 0x2A"), (0x05, "Input 0x05"),
    ])
    func inputNames(code: Int, name: String) {
        #expect(InputSource.name(code) == name)
    }

    @Test func everyCommonInputHasARealName() {
        #expect(InputSource.common.allSatisfy { !InputSource.name($0).hasPrefix("Input 0x") })
    }
}

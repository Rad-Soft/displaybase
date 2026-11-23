//
//  DDCPacketTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Testing

struct DDCPacketTests {
    @Test("a read request is a length, the body, and a checksum over the bus addresses too")
    func readRequest() {
        #expect(DDC.packet(for: [0x01, 0x60]) == [0x82, 0x01, 0x60, 0xDC])
    }

    @Test("a write carries the value as two bytes")
    func writeRequest() {
        #expect(DDC.packet(for: [0x03, 0x60, 0x00, 0x11]) == [0x84, 0x03, 0x60, 0x00, 0x11, 0xC9])
    }

    /// A reply to a read of `code`, with a checksum that's right unless asked otherwise.
    func reply(code: UInt8 = 0x60, value: Int = 0x0F11, opcode: UInt8 = 0x02, result: UInt8 = 0, goodChecksum: Bool = true) -> [UInt8] {
        var bytes: [UInt8] = [0x6E, 0x88, opcode, result, code, 0, 0xFF, 0xFF, UInt8(value >> 8), UInt8(value & 0xFF)]
        let checksum = bytes.reduce(0x50, ^)
        bytes.append(goodChecksum ? checksum : checksum ^ 0xFF)
        bytes.append(0)
        return bytes
    }

    @Test("a good reply gives the value")
    func goodReply() {
        #expect(DDC.value(fromReply: reply(), code: 0x60) == 0x0F11)
        #expect(DDC.value(fromReply: reply(value: 0x0011), code: 0x60) == 0x11)
    }

    @Test("anything off about the reply means no value", arguments: [
        ("another code", 0),
        ("not a read reply", 1),
        ("the monitor reporting an error", 2),
        ("a bad checksum", 3),
    ])
    func badReply(name: String, kind: Int) {
        let bytes: [UInt8]
        switch kind {
        case 0: bytes = reply(code: 0x10)
        case 1: bytes = reply(opcode: 0x03)
        case 2: bytes = reply(result: 1)
        default: bytes = reply(goodChecksum: false)
        }
        #expect(DDC.value(fromReply: bytes, code: 0x60) == nil, "\(name)")
    }

    @Test("a reply cut short is rejected rather than read past its end")
    func shortReply() {
        #expect(DDC.value(fromReply: [0x6E, 0x88, 0x02], code: 0x60) == nil)
        #expect(DDC.value(fromReply: [], code: 0x60) == nil)
    }
}

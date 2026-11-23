//
//  USBDeviceTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

struct USBDeviceTests {
    @Test func nameDoesNotMatter() {
        let a = USBDeviceID(vendor: 0x046D, product: 0xC31C, name: "Keyboard")
        let b = USBDeviceID(vendor: 0x046D, product: 0xC31C, name: "Other")
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
        #expect(a != USBDeviceID(vendor: 0x046D, product: 0xC31D, name: "Keyboard"))
        #expect(a != USBDeviceID(vendor: 0x046E, product: 0xC31C, name: "Keyboard"))
    }

    @Test("ids are zero padded uppercase hex", arguments: [
        (0x046D, 0xC31C, "046D:C31C"),
        (0x1, 0xA, "0001:000A"),
        (0, 0, "0000:0000"),
        (0xFFFF, 0xFFFF, "FFFF:FFFF"),
    ])
    func identifier(vendor: Int, product: Int, expected: String) {
        #expect(USBDeviceID(vendor: vendor, product: product, name: "").id == expected)
    }

    @Test func codableKeepsEverything() throws {
        let device = USBDeviceID(vendor: 0x046D, product: 0xC31C, name: "Keyboard")
        let again = try JSONDecoder().decode(USBDeviceID.self, from: JSONEncoder().encode(device))
        #expect(again.name == "Keyboard" && again.vendor == 0x046D && again.product == 0xC31C)
    }
}

//
//  RemoteTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Testing

struct RemoteTests {
    let keyboard = USBDeviceID(vendor: 0x046D, product: 0xC31C, name: "Keyboard")

    @Test func windows() {
        let output = "Instance ID:  USB\\VID_046D&PID_C31C\\6&2A\nDevice Description: USB Composite Device"
        #expect(RemoteSystem.windows.lists(keyboard, in: output))
        #expect(RemoteSystem.windows.lists(keyboard, in: output.lowercased()))
        #expect(!RemoteSystem.windows.lists(keyboard, in: "USB\\VID_046D&PID_C31D\\1"))
    }

    @Test func linux() {
        #expect(RemoteSystem.linux.lists(keyboard, in: "Bus 001 Device 004: ID 046d:c31c Logitech, Inc. Keyboard"))
        #expect(!RemoteSystem.linux.lists(keyboard, in: "Bus 001 Device 004: ID 046d:c31d Logitech, Inc. Mouse"))
    }

    @Test("ids have to be on the same device")
    func mac() {
        let match = "+-o Keyboard\n  {\n    \"idVendor\" = 1133\n    \"idProduct\" = 49948\n  }"
        let split = "+-o Hub\n  | {\n  |   \"idVendor\" = 1133\n  | }\n+-o Other\n  {\n    \"idProduct\" = 49948\n  }"
        #expect(RemoteSystem.mac.lists(keyboard, in: match))
        #expect(!RemoteSystem.mac.lists(keyboard, in: split))
        #expect(!RemoteSystem.mac.lists(keyboard, in: match.replacing("49948", with: "499480")))
    }

    @Test("a host can't smuggle in ssh options", arguments: [
        ("gaming", true),
        ("me@192.0.2.10", true),
        ("", false),
        ("-oProxyCommand=true", false),
        ("a b", false),
    ])
    func hosts(host: String, safe: Bool) {
        #expect(RemoteComputer.isSafe(host) == safe)
    }
}

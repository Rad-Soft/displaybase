//
//  RemoteSystemTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Testing

struct RemoteSystemTests {
    let small = USBDeviceID(vendor: 0x1, product: 0xA, name: "Small")

    @Test("empty output lists nothing", arguments: RemoteSystem.allCases)
    func empty(system: RemoteSystem) {
        #expect(!system.lists(small, in: ""))
    }

    @Test func idsArePadded() {
        #expect(RemoteSystem.windows.lists(small, in: "USB\\VID_0001&PID_000A\\1"))
        #expect(!RemoteSystem.windows.lists(small, in: "USB\\VID_1&PID_A\\1"))
        #expect(RemoteSystem.linux.lists(small, in: "Bus 001 Device 002: ID 0001:000a Thing"))
        #expect(RemoteSystem.linux.lists(small, in: "Bus 001 Device 002: ID 0001:000A Thing"))
    }

    @Test func linuxNeedsTheWholeId() {
        let keyboard = USBDeviceID(vendor: 0x046D, product: 0xC31C, name: "Keyboard")
        #expect(!RemoteSystem.linux.lists(keyboard, in: "ID 046d:c31"))
        #expect(!RemoteSystem.linux.lists(keyboard, in: "046d:c31c"))
    }

    @Test func macReadsIndentedTreeLines() {
        let output = "+-o Hub  <class IOUSBHostDevice>\n  | {\n  |   \"idVendor\" = 1\n  |   \"idProduct\" = 10\n  | }"
        #expect(RemoteSystem.mac.lists(small, in: output))
    }

    @Test func macDoesNotMatchLongerIds() {
        let output = "+-o Hub\n  {\n    \"idVendor\" = 11\n    \"idProduct\" = 10\n  }"
        #expect(!RemoteSystem.mac.lists(small, in: output))
    }

    @Test func macFindsTheRightBlockAmongMany() {
        let other = "+-o Mouse\n  {\n    \"idVendor\" = 5\n    \"idProduct\" = 6\n  }\n"
        let ours = "+-o Thing\n  {\n    \"idVendor\" = 1\n    \"idProduct\" = 10\n  }"
        #expect(RemoteSystem.mac.lists(small, in: other + ours))
    }

    @Test("every system has a label and a command", arguments: RemoteSystem.allCases)
    func labels(system: RemoteSystem) {
        #expect(!system.label.isEmpty && !system.listCommand.isEmpty)
        #expect(system.id == system)
    }
}

//
//  OptionalScreenTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Foundation
import Testing

@MainActor
struct OptionalScreenTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    /// Goes (hands over), Stay (stays) and Extra (optional, follows the keyboard).
    func threeScreens() {
        desk.add("Goes", role: .goes)
        desk.add("Stay")
        desk.add("Extra", role: .optional)
        desk.prefs.everyScreen = true
    }

    @Test("without a switch to follow, optional screens go with the hand-over")
    func goesAlong() async {
        threeScreens()
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")

        #expect(desk.monitor("Extra").input == 0x11)
        let extra = desk.prefs.handover?.away.first { $0.monitor == desk.id("Extra") }
        #expect(extra?.optional == true && extra?.display == desk.display("Extra").id && extra?.macInput == 0x0F)
        #expect(!desk.display("Extra").active && desk.display("Stay").active)
        #expect(controller.everyScreenAway)
        #expect(desk.log.contains("lent windows capture"))
        #expect(!desk.displays.lostEveryScreen)
    }

    @Test("with no other screen to fall back to, the last one stays on, out of sight")
    func lastOneStays() async {
        desk.add("Goes", role: .goes)
        desk.add("Extra", role: .optional)
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")

        #expect(desk.monitor("Extra").input == 0x11)
        #expect(desk.display("Extra").active)
        let extra = desk.prefs.handover?.away.first { $0.monitor == desk.id("Extra") }
        #expect(extra?.optional == true && extra?.display == nil)
        #expect(!desk.log.contains("lent windows capture"))
        #expect(!desk.displays.lostEveryScreen)
    }

    @Test("a laptop to fall back to is enough to turn the last optional screen off")
    func laptopFallback() async {
        desk.add("Goes", role: .goes)
        desk.add("Extra", role: .optional)
        desk.addLaptop()
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        #expect(!desk.display("Extra").active && desk.display("Built-in Display").active)
        #expect(desk.log.contains("lent windows capture"))
    }

    @Test("with two optional screens and nothing else, one stays on")
    func twoOptionalsNoFallback() async {
        desk.add("Goes", role: .goes)
        desk.add("First", role: .optional)
        desk.add("Second", role: .optional)
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")

        #expect(desk.monitor("First").input == 0x11 && desk.monitor("Second").input == 0x11)
        let active = ["First", "Second"].filter { desk.display($0).active }
        #expect(active.count == 1)
        #expect(!desk.displays.lostEveryScreen)
    }

    @Test("optional screens stay put when the setting is off")
    func settingOff() async {
        threeScreens()
        desk.prefs.everyScreen = false
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        #expect(desk.monitor("Extra").input == 0x0F && !controller.everyScreenAway)
        #expect(desk.prefs.handover?.away.count == 1)
    }

    @Test("and when there are none, the setting does nothing")
    func noOptionalScreens() async {
        desk.add("Goes", role: .goes)
        desk.add("Stay")
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        #expect(desk.prefs.handover?.away.count == 1 && !controller.everyScreenAway)
    }

    @Test("an optional screen that won't switch is left on the Mac")
    func optionalRefuses() async {
        threeScreens()
        desk.prefs.followSwitch = false
        desk.monitor("Extra").refusesSwitch = true
        await controller.handOver("shortcut")
        #expect(controller.note == "Extra didn't switch to PC.")
        #expect(desk.display("Extra").active && !controller.everyScreenAway)
        #expect(!desk.log.contains("lent windows capture") || desk.log.contains("lent windows forget"))
        #expect(controller.mode == .pc)
    }

    @Test("optional screens follow the keyboard to the other computer and back")
    func followsKeyboard() async {
        threeScreens()
        desk.useSwitch()
        desk.usb.startPresent(true)
        controller.watchSwitchDevice()
        await controller.handOver("shortcut")
        #expect(!controller.everyScreenAway && desk.monitor("Extra").input == 0x0F)

        // keyboard leaves: no way to ask the other computer, so leaving is enough
        desk.usb.plug(false)
        await controller.followTask?.value
        #expect(controller.everyScreenAway && desk.monitor("Extra").input == 0x11)
        #expect(!desk.display("Extra").active && desk.display("Stay").active)

        // and comes back: the Mac gets its optional screen back, the main one stays over there
        desk.usb.plug(true)
        await settle("optional screen to return") { !controller.everyScreenAway }
        #expect(desk.monitor("Extra").input == 0x0F && desk.display("Extra").active)
        #expect(controller.mode == .pc && desk.monitor("Goes").input == 0x11)
        #expect(desk.log.contains("lent windows restore Extra") && desk.log.contains("lent windows forget"))
        #expect(desk.displays.main?.monitor.name == "Extra")
    }

    @Test("an optional screen that won't come back stays on the list for next time")
    func reclaimRefuses() async {
        threeScreens()
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        desk.monitor("Extra").refusesSwitch = true
        desk.prefs.followSwitch = true
        desk.prefs.switchDevice = USBDeviceID(vendor: 1, product: 2, name: "Keyboard")
        controller.switchSpot = .mac
        await controller.resyncOptional()

        #expect(controller.note == "Extra didn't come back. Use the input button on the monitor.")
        #expect(controller.everyScreenAway)
        // macOS has it back, so the entry no longer claims it's turned off
        #expect(desk.display("Extra").active)
        #expect(desk.prefs.handover?.away.first { $0.optional }?.display == nil)
        #expect(!controller.busy)
    }

    @Test("reclaiming brings an optional screen back and nothing else")
    func reclaimDetails() async {
        threeScreens()
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        desk.prefs.followSwitch = true
        desk.prefs.switchDevice = USBDeviceID(vendor: 1, product: 2, name: "Keyboard")
        controller.switchSpot = .mac
        desk.log.clear()

        await controller.resyncOptional()
        #expect(!controller.everyScreenAway && desk.display("Extra").active)
        #expect(desk.prefs.handover?.away.map(\.monitor.name) == ["Goes"])
        #expect(desk.monitor("Goes").input == 0x11 && !desk.display("Goes").active)
        #expect(desk.log.happened("enable Extra", before: "ddc Extra 0xf"))
        #expect(!controller.busy)
    }

    @Test("a screen that stays on when reclaimed needs no layout fixing")
    func reclaimWithoutDisabled() async {
        desk.add("Goes", role: .goes)
        desk.add("Extra", role: .optional)
        desk.prefs.everyScreen = true
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        desk.prefs.followSwitch = true
        desk.prefs.switchDevice = USBDeviceID(vendor: 1, product: 2, name: "Keyboard")
        controller.switchSpot = .mac
        desk.log.clear()

        await controller.resyncOptional()
        #expect(desk.monitor("Extra").input == 0x0F && !controller.everyScreenAway)
        #expect(!desk.log.contains("lent windows forget") && !desk.log.events.contains { $0.hasPrefix("main") })
    }

    @Test("taking back brings optional screens home with everything else")
    func takeBackWithOptional() async {
        threeScreens()
        desk.prefs.followSwitch = false
        await controller.handOver("shortcut")
        await controller.takeBack("shortcut")

        #expect(controller.mode == .mac && desk.prefs.handover == nil)
        #expect(["Goes", "Stay", "Extra"].allSatisfy { desk.display($0).active })
        #expect(["Goes", "Stay", "Extra"].allSatisfy { desk.monitor($0).input == 0x0F })
        #expect(desk.log.contains("lent windows forget"))
        #expect(!controller.everyScreenAway)
    }

    @Test("resyncing does nothing while busy or when the Mac is in charge")
    func resyncGuards() async {
        threeScreens()
        desk.prefs.followSwitch = false
        await controller.resyncOptional()
        #expect(desk.log.events.isEmpty)
        await controller.handOver("shortcut")
        desk.log.clear()
        controller.busy = true
        await controller.resyncOptional()
        #expect(desk.log.events.isEmpty)
    }

    @Test("an optional screen that isn't connected is skipped")
    func optionalMissing() async {
        threeScreens()
        desk.prefs.followSwitch = false
        desk.display("Extra").active = false
        await controller.handOver("shortcut")
        #expect(!controller.everyScreenAway && desk.monitor("Extra").writes.isEmpty)
    }
}

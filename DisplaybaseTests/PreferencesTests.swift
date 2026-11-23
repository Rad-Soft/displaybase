//
//  PreferencesTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct PreferencesTests {
    let main = MonitorID(vendor: 1, model: 1, serial: 1, name: "Main")
    let side = MonitorID(vendor: 1, model: 2, serial: 1, name: "Side")

    func withDefaults(_ body: (UserDefaults) -> Void) {
        let name = "displaybase.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }

    @Test func defaults() {
        withDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            #expect(prefs.pcName == "PC")
            #expect(prefs.remoteHost.isEmpty)
            #expect(prefs.remoteSystem == .windows)
            #expect(prefs.followSwitch)
            #expect(!prefs.switchBackTakesBack)
            #expect(!prefs.everyScreen)
            #expect(prefs.handover == nil)
            #expect(!prefs.hasOptional)
        }
    }

    @Test func remembersEverything() {
        withDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            prefs.screens = [DeskScreen(monitor: main, role: .goes, rotation: 90)]
            prefs.pcName = "Gaming"
            prefs.remoteHost = "me@192.0.2.10"
            prefs.remoteSystem = .linux
            prefs.followSwitch = false
            prefs.switchBackTakesBack = true
            prefs.everyScreen = true
            prefs.switchDevice = USBDeviceID(vendor: 0x046D, product: 0xC31C, name: "Keyboard")
            prefs.shortcut = Shortcut(keyCode: 0, modifiers: 0, key: "A")
            prefs.handover = Handover(away: [.init(monitor: main)], layout: nil, keyboardOnPC: true)
            prefs.setupDone = true

            let again = Preferences(defaults: defaults)
            #expect(again.screens == prefs.screens && again.screens[0].rotation == 90)
            #expect(again.pcName == "Gaming")
            #expect(again.remoteHost == "me@192.0.2.10")
            #expect(again.remoteSystem == .linux)
            #expect(!again.followSwitch)
            #expect(again.switchBackTakesBack)
            #expect(again.everyScreen)
            #expect(again.switchDevice?.id == "046D:C31C" && again.switchDevice?.name == "Keyboard")
            #expect(again.shortcut == Shortcut(keyCode: 0, modifiers: 0, key: "A"))
            #expect(again.handover?.keyboardOnPC == true)
            #expect(again.setupDone)
        }
    }

    @Test func clearingRemovesStoredValues() {
        withDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            prefs.handover = Handover(away: [.init(monitor: main)], layout: nil)
            prefs.switchDevice = USBDeviceID(vendor: 1, product: 2, name: "x")
            prefs.handover = nil
            prefs.switchDevice = nil
            let again = Preferences(defaults: defaults)
            #expect(again.handover == nil && again.switchDevice == nil)
            #expect(defaults.object(forKey: "handover") == nil)
        }
    }

    @Test("corrupt stored data falls back to defaults", arguments: ["screens", "switchDevice", "shortcut", "handover"])
    func corrupt(key: String) {
        withDefaults { defaults in
            defaults.set(Data("not json".utf8), forKey: key)
            let prefs = Preferences(defaults: defaults)
            #expect(prefs.screens.isEmpty && prefs.switchDevice == nil && prefs.handover == nil)
            #expect(prefs.shortcut == .standard)
        }
    }

    @Test func unknownSystemFallsBack() {
        withDefaults { defaults in
            defaults.set("beos", forKey: "remoteSystem")
            #expect(Preferences(defaults: defaults).remoteSystem == .windows)
        }
    }

    @Test func updateChangesOneScreen() {
        withDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            prefs.screens = [DeskScreen(monitor: main), DeskScreen(monitor: side)]
            prefs.update(side) {
                $0.role = .optional
                $0.macInput = 0x1B
            }
            #expect(prefs.screens[0].role == .stays)
            #expect(prefs.screens[1].role == .optional && prefs.screens[1].macInput == 0x1B)
            #expect(Preferences(defaults: defaults).screens[1].role == .optional)
        }
    }

    @Test func updateIgnoresUnknownMonitors() {
        withDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            prefs.screens = [DeskScreen(monitor: main)]
            prefs.update(side) { $0.role = .goes }
            #expect(prefs.screens == [DeskScreen(monitor: main)])
            #expect(prefs.screen(side) == nil)
            #expect(prefs.screen(main)?.monitor == main)
        }
    }

    @Test func derivedFlags() {
        withDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            prefs.screens = [DeskScreen(monitor: main, role: .goes)]
            #expect(!prefs.hasOptional)
            prefs.screens.append(DeskScreen(monitor: side, role: .optional))
            #expect(prefs.hasOptional)
            #expect(!prefs.hasRemote)
            prefs.remoteHost = "gaming"
            #expect(prefs.hasRemote)
        }
    }

    @Test func pcLabel() {
        withDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            #expect(prefs.pcLabel == "PC")
            prefs.pcName = ""
            #expect(prefs.pcLabel == "the other computer")
            prefs.pcName = "Studio"
            #expect(prefs.pcLabel == "Studio")
        }
    }
}

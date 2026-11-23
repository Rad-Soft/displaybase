//
//  LinkTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Testing

@MainActor
struct LinkTests {
    let desk = SimulatedDesk()
    var controller: DeskController { desk.controller }

    func link(_ text: String) {
        controller.handle(URL(string: text)!)
    }

    func twoScreens() {
        desk.add("Left", role: .goes)
        desk.add("Right")
    }

    @Test("links are off by default, so a web page can't move the screens")
    func offByDefault() async {
        twoScreens()
        #expect(!desk.prefs.allowLinks)
        link("displaybase://pc")
        link("displaybase://toggle")
        await drain()
        #expect(controller.mode == .mac && desk.log.events.isEmpty)
    }

    @Test("with links on, pc hands over and mac takes back")
    func pcAndMac() async {
        twoScreens()
        desk.prefs.allowLinks = true
        link("displaybase://pc")
        await settle("hand-over") { controller.mode == .pc }
        #expect(desk.monitor("Left").input == 0x11)

        link("displaybase://mac")
        await settle("take-back") { controller.mode == .mac }
        #expect(desk.monitor("Left").input == 0x0F)
    }

    @Test("toggle goes whichever way is next")
    func toggle() async {
        twoScreens()
        desk.prefs.allowLinks = true
        link("displaybase://toggle")
        await settle("hand-over") { controller.mode == .pc }
        link("displaybase://toggle")
        await settle("take-back") { controller.mode == .mac }
    }

    @Test("other schemes and unknown commands do nothing")
    func ignored() async {
        twoScreens()
        desk.prefs.allowLinks = true
        link("https://pc")
        link("displaybase://elsewhere")
        link("displaybase:")
        await drain()
        #expect(controller.mode == .mac && desk.log.events.isEmpty)
    }

    @Test("the shortcut toggles the same way, with the reason noted")
    func shortcutPress() async {
        twoScreens()
        controller.start()
        desk.hotkey.action()
        await settle("hand-over") { controller.mode == .pc }
        desk.hotkey.action()
        await settle("take-back") { controller.mode == .mac }
    }

    @Test("starting registers the saved shortcut and says when it's taken")
    func registering() {
        controller.start()
        #expect(desk.hotkey.registered == desk.prefs.shortcut && !controller.shortcutTaken)

        let taken = SimulatedDesk()
        taken.hotkey.available = false
        taken.controller.start()
        #expect(taken.controller.shortcutTaken)
    }

    @Test("a new shortcut is registered, and pausing lets go of the old one")
    func changing() {
        controller.start()
        controller.pauseShortcut()
        #expect(desk.hotkey.registered == nil)

        desk.prefs.shortcut = Shortcut(keyCode: 0, modifiers: 0x100, key: "A")
        controller.shortcutChanged()
        #expect(desk.hotkey.registered?.key == "A" && !controller.shortcutTaken)
    }

    @Test("nothing is registered before the app has started")
    func notStarted() {
        controller.shortcutChanged()
        #expect(desk.hotkey.registered == nil)
    }

    @Test("asking for window access goes to the system")
    func windowAccess() {
        controller.allowWindowRestore()
        #expect(desk.windows.accessRequests == 1)
    }
}

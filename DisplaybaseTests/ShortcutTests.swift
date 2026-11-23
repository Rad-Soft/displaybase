//
//  ShortcutTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import AppKit
import Carbon.HIToolbox
import Testing

@MainActor
struct ShortcutTests {
    func event(_ characters: String, flags: NSEvent.ModifierFlags, keyCode: UInt16 = 2) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
            context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: keyCode
        )!
    }

    @Test("labels list modifiers in macOS order", arguments: [
        (controlKey, "⌃X"),
        (optionKey, "⌥X"),
        (shiftKey, "⇧X"),
        (cmdKey, "⌘X"),
        (controlKey | optionKey | shiftKey | cmdKey, "⌃⌥⇧⌘X"),
        (cmdKey | shiftKey, "⇧⌘X"),
        (0, "X"),
    ])
    func labels(modifiers: Int, expected: String) {
        #expect(Shortcut(keyCode: 7, modifiers: modifiers, key: "X").label == expected)
    }

    @Test func readsAnEvent() throws {
        let shortcut = try #require(Shortcut(event: event("d", flags: [.control, .option, .command], keyCode: UInt16(kVK_ANSI_D))))
        #expect(shortcut == .standard)
        #expect(shortcut.key == "D")
    }

    @Test func shiftIsKept() throws {
        let shortcut = try #require(Shortcut(event: event("k", flags: [.command, .shift])))
        #expect(shortcut.modifiers == cmdKey | shiftKey)
        #expect(shortcut.label == "⇧⌘K")
    }

    @Test("needs control, option or command", arguments: [
        NSEvent.ModifierFlags([]), .shift, .capsLock, [.shift, .capsLock],
    ])
    func rejectsWeakModifiers(flags: NSEvent.ModifierFlags) {
        #expect(Shortcut(event: event("d", flags: flags)) == nil)
    }

    @Test("rejects keys that can't be named", arguments: [" ", "", "\u{F700}", "\r"])
    func rejectsOddKeys(characters: String) {
        #expect(Shortcut(event: event(characters, flags: .command)) == nil)
    }

    @Test func codable() throws {
        let data = try JSONEncoder().encode(Shortcut.standard)
        #expect(try JSONDecoder().decode(Shortcut.self, from: data) == .standard)
    }
}

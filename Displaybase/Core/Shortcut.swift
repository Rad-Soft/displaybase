//
//  Shortcut.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import AppKit
import Carbon.HIToolbox

struct Shortcut: Codable, Hashable, Sendable {
    var keyCode: Int
    // Carbon's modifier bits, which is what registering needs
    var modifiers: Int
    var key: String

    static let standard = Shortcut(keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey | cmdKey, key: "D")

    var label: String {
        var symbols = ""
        if modifiers & controlKey != 0 { symbols += "⌃" }
        if modifiers & optionKey != 0 { symbols += "⌥" }
        if modifiers & shiftKey != 0 { symbols += "⇧" }
        if modifiers & cmdKey != 0 { symbols += "⌘" }
        return symbols + key
    }
}

extension Shortcut {
    /// nil unless there's a real modifier, so a plain letter can't be taken over everywhere.
    @MainActor
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        var modifiers = 0
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.command) { modifiers |= cmdKey }
        guard modifiers & (controlKey | optionKey | cmdKey) != 0,
              let key = event.charactersIgnoringModifiers?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
              let first = key.unicodeScalars.first, first.value >= 0x21, first.value < 0xF700 else { return nil }
        self.init(keyCode: Int(event.keyCode), modifiers: modifiers, key: key)
    }
}

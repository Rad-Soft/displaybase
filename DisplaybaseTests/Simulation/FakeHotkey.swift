//
//  FakeHotkey.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

@MainActor
final class FakeHotkey: DeskHotkey {
    var action: () -> Void = {}
    var available = true
    private(set) var registered: Shortcut?
    private(set) var unregisterCalls = 0

    func register(_ shortcut: Shortcut) -> Bool {
        guard available else { return false }
        registered = shortcut
        return true
    }

    func unregister() {
        unregisterCalls += 1
        registered = nil
    }
}

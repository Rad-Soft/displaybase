//
//  Hotkey.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import Carbon.HIToolbox

/// A system-wide shortcut. Carbon is still the only API that doesn't need Accessibility access for this.
@MainActor
final class Hotkey: DeskHotkey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: () -> Void = {}

    // installed on first use, so making one doesn't touch the event system
    private func install() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, refcon in
            guard let refcon else { return noErr }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { hotkey.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// False when another app already has it.
    func register(_ shortcut: Shortcut) -> Bool {
        install()
        unregister()
        let id = EventHotKeyID(signature: 0x4442_4153, id: 1)
        return RegisterEventHotKey(UInt32(shortcut.keyCode), UInt32(shortcut.modifiers), id, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }
}

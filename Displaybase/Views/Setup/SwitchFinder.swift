//
//  SwitchFinder.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Observation

/// Works out what's on a USB switch by watching what disappears when its button is pressed.
@MainActor
@Observable
final class SwitchFinder {
    private(set) var found: [USBDeviceID] = []

    func watch() async {
        let before = USBWatcher.connectedDevices()
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(600))
            let now = Set(USBWatcher.connectedDevices())
            for device in before where !now.contains(device) && !found.contains(device) {
                found.append(device)
            }
        }
    }

    var best: USBDeviceID? {
        found.first { $0.name.localizedCaseInsensitiveContains("keyboard") } ?? found.first
    }
}

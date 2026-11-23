//
//  FakeSwitchDevice.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// The keyboard switch's USB device, which arrives and leaves as the switch moves.
@MainActor
final class FakeSwitchDevice: DeskSwitchDevice {
    private(set) var isPresent = false
    var onChange: ((Bool) -> Void)?
    private(set) var watched: USBDeviceID?

    func watch(_ device: USBDeviceID?) {
        watched = device
    }

    func plug(_ present: Bool) {
        isPresent = present
        onChange?(present)
    }

    /// Present without telling anyone, like a device that was already there at launch.
    func startPresent(_ present: Bool) {
        isPresent = present
    }
}

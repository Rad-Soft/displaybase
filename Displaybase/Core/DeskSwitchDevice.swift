//
//  DeskSwitchDevice.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// The USB device that follows the keyboard switch.
@MainActor
protocol DeskSwitchDevice: AnyObject {
    var isPresent: Bool { get }
    var onChange: ((Bool) -> Void)? { get set }
    func watch(_ device: USBDeviceID?)
}

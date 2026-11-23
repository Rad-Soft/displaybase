//
//  DeskRemote.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// The other computer, asked over SSH.
@MainActor
protocol DeskRemote: AnyObject {
    func isReachable(host: String) async -> Bool
    /// nil means it couldn't be asked, which is different from "it doesn't have the device".
    func has(_ device: USBDeviceID, host: String, system: RemoteSystem) async -> Bool?
}

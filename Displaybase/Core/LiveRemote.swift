//
//  LiveRemote.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

@MainActor
final class LiveRemote: DeskRemote {
    func isReachable(host: String) async -> Bool {
        await RemoteComputer.isReachable(host: host)
    }

    func has(_ device: USBDeviceID, host: String, system: RemoteSystem) async -> Bool? {
        await RemoteComputer.has(device, host: host, system: system)
    }
}

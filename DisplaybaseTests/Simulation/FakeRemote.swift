//
//  FakeRemote.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// The other computer, which can be off, can lack the device, or not answer questions at all.
@MainActor
final class FakeRemote: DeskRemote {
    var online = true
    // nil means ssh can't be used to ask
    var hasDevice: Bool? = true
    private(set) var reachableChecks = 0
    private(set) var deviceChecks = 0

    func isReachable(host: String) async -> Bool {
        reachableChecks += 1
        return online
    }

    func has(_ device: USBDeviceID, host: String, system: RemoteSystem) async -> Bool? {
        deviceChecks += 1
        return hasDevice
    }
}

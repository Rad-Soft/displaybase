//
//  RemoteSystem.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

enum RemoteSystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case windows
    case linux
    case mac

    var id: Self { self }

    var label: String {
        switch self {
        case .windows: "Windows"
        case .linux: "Linux"
        case .mac: "macOS"
        }
    }

    var listCommand: String {
        switch self {
        case .windows: "pnputil /enum-devices /connected"
        case .linux: "lsusb"
        case .mac: "ioreg -r -c IOUSBHostDevice -l -w0"
        }
    }

    func lists(_ device: USBDeviceID, in output: String) -> Bool {
        switch self {
        case .windows:
            let needle = String(format: "VID_%04X&PID_%04X", device.vendor, device.product)
            return output.range(of: needle, options: .caseInsensitive) != nil
        case .linux:
            let needle = String(format: "ID %04x:%04x", device.vendor, device.product)
            return output.range(of: needle, options: .caseInsensitive) != nil
        case .mac:
            // ioreg prints ids in decimal, one block per device
            return output.components(separatedBy: "+-o ").contains { block in
                let lines = block.split(separator: "\n").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " |")) }
                return lines.contains("\"idVendor\" = \(device.vendor)") && lines.contains("\"idProduct\" = \(device.product)")
            }
        }
    }
}

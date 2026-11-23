//
//  USBWatcher.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import Foundation
import IOKit

struct USBDeviceID: Codable, Hashable, Sendable, Identifiable {
    var vendor: Int
    var product: Int
    var name: String

    var id: String { String(format: "%04X:%04X", vendor, product) }

    static func == (lhs: USBDeviceID, rhs: USBDeviceID) -> Bool {
        lhs.vendor == rhs.vendor && lhs.product == rhs.product
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(vendor)
        hasher.combine(product)
    }
}

/// Watches one USB device come and go. A KVM switch shows up here as its devices detaching from the Mac.
@MainActor
final class USBWatcher: DeskSwitchDevice {
    private(set) var isPresent = false
    var onChange: ((Bool) -> Void)?

    private var port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var device: USBDeviceID?
    private var settle: Task<Void, Never>?

    func watch(_ device: USBDeviceID?) {
        stop()
        self.device = device
        guard let device else {
            isPresent = false
            return
        }
        isPresent = Self.isConnected(device)

        let port = IONotificationPortCreate(kIOMainPortDefault)
        self.port = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .commonModes)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(port, type, Self.matching(device), { refcon, iterator in
                USBWatcher.drain(iterator)
                guard let refcon else { return }
                let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { watcher.deviceEvent() }
            }, refcon, &iterator)
            guard result == KERN_SUCCESS else { continue }
            Self.drain(iterator)
            iterators.append(iterator)
        }
    }

    func stop() {
        settle?.cancel()
        iterators.forEach { IOObjectRelease($0) }
        iterators.removeAll()
        if let port { IONotificationPortDestroy(port) }
        port = nil
    }

    // USB re-enumeration can flicker, so wait for it to settle before calling it a move
    private func deviceEvent() {
        settle?.cancel()
        settle = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled, let self, let device = self.device else { return }
            let present = Self.isConnected(device)
            guard present != self.isPresent else { return }
            self.isPresent = present
            self.onChange?(present)
        }
    }

    static func isConnected(_ device: USBDeviceID) -> Bool {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching(device), &iterator) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }
        let first = IOIteratorNext(iterator)
        defer { if first != 0 { IOObjectRelease(first) } }
        return first != 0
    }

    /// Everything plugged in right now except hubs, for the settings picker.
    static func connectedDevices() -> [USBDeviceID] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var devices = Set<USBDeviceID>()
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }
            func property<T>(_ key: String) -> T? {
                IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? T
            }
            guard let vendor: Int = property("idVendor"), let product: Int = property("idProduct") else { continue }
            if let deviceClass: Int = property("bDeviceClass"), deviceClass == 9 { continue }
            let name: String = property("USB Product Name") ?? String(format: "%04X:%04X", vendor, product)
            devices.insert(USBDeviceID(vendor: vendor, product: product, name: name))
        }
        return devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func matching(_ device: USBDeviceID) -> CFDictionary {
        let dict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        dict["idVendor"] = device.vendor
        dict["idProduct"] = device.product
        return dict
    }

    private nonisolated static func drain(_ iterator: io_iterator_t) {
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
    }
}

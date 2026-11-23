//
//  DDC.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import Foundation
import IOKit

@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(_ service: CFTypeRef, _ chip: UInt32, _ offset: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn
@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chip: UInt32, _ address: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn
@_silgen_name("IOAVServiceCopyEDID")
private func IOAVServiceCopyEDID(_ service: CFTypeRef, _ edid: UnsafeMutablePointer<Unmanaged<CFData>?>) -> IOReturn

/// A monitor as its EDID describes it. The same values come back from CGDisplayVendorNumber and friends,
/// which is how a DDC port gets matched to a macOS display.
struct MonitorID: Codable, Hashable, Sendable {
    var vendor: UInt32
    var model: UInt32
    var serial: UInt32
    var name: String

    static func == (lhs: MonitorID, rhs: MonitorID) -> Bool {
        lhs.vendor == rhs.vendor && lhs.model == rhs.model && lhs.serial == rhs.serial
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(vendor)
        hasher.combine(model)
        hasher.combine(serial)
    }
}

enum VCP {
    static let input: UInt8 = 0x60
}

enum InputSource {
    // what to offer when a monitor won't say which inputs it has
    static let common = [0x0F, 0x10, 0x11, 0x12, 0x15, 0x19, 0x1B]

    static func name(_ code: Int) -> String {
        switch code {
        case 0x01: "VGA"
        case 0x03: "DVI"
        case 0x04: "DVI 2"
        case 0x0F: "DisplayPort"
        case 0x10: "DisplayPort 2"
        case 0x11: "HDMI"
        case 0x12: "HDMI 2"
        case 0x15, 0x19, 0x1B: "Thunderbolt / USB-C"
        default: String(format: "Input 0x%02X", code)
        }
    }
}

/// DDC/CI through the DCP AV services on Apple Silicon. Every call blocks for 50-300 ms, so stay off the main actor.
enum DDC {
    private static let lock = NSLock()

    private struct Port {
        let monitor: MonitorID
        let service: CFTypeRef
    }

    static func monitors() -> [MonitorID] {
        lock.withLock { ports().map(\.monitor) }
    }

    static func read(_ code: UInt8, on monitor: MonitorID) -> Int? {
        lock.withLock {
            guard let port = ports().first(where: { $0.monitor == monitor }) else { return nil }
            return read(code, service: port.service)
        }
    }

    static func write(_ code: UInt8, value: Int, on monitor: MonitorID) -> Bool {
        lock.withLock {
            guard let port = ports().first(where: { $0.monitor == monitor }) else { return false }
            return send([0x03, code, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)], to: port.service)
        }
    }

    /// Input codes the monitor lists under VCP 0x60 in its capabilities string.
    static func inputs(of monitor: MonitorID) -> [Int] {
        capabilities(of: monitor).map(parseInputs) ?? []
    }

    static func parseInputs(_ capabilities: String) -> [Int] {
        guard let match = capabilities.firstMatch(of: #/(?:^|[\s(])60\s*\(([0-9A-Fa-f\s]*)\)/#) else { return [] }
        return match.1.split(whereSeparator: \.isWhitespace).compactMap { Int($0, radix: 16) }
    }

    static func capabilities(of monitor: MonitorID) -> String? {
        lock.withLock {
            guard let port = ports().first(where: { $0.monitor == monitor }) else { return nil }
            var bytes = [UInt8]()
            var offset = 0
            var misses = 0
            while offset < 4096 && misses < 4 {
                guard send([0xF3, UInt8(offset >> 8), UInt8(offset & 0xFF)], to: port.service) else {
                    misses += 1
                    usleep(80_000)
                    continue
                }
                usleep(60_000)
                var reply = [UInt8](repeating: 0, count: 38)
                let status = reply.withUnsafeMutableBytes { IOAVServiceReadI2C(port.service, 0x37, 0x51, $0.baseAddress!, 38) }
                guard status == kIOReturnSuccess, reply[2] == 0xE3 else {
                    misses += 1
                    continue
                }
                let length = Int(reply[1] & 0x7F) - 3
                if length <= 0 { break }
                guard Int(reply[3]) << 8 | Int(reply[4]) == offset else {
                    misses += 1
                    continue
                }
                bytes += reply[5..<(5 + min(length, 32))]
                offset += length
                misses = 0
            }
            return bytes.isEmpty ? nil : String(decoding: bytes.filter { $0 != 0 }, as: UTF8.self)
        }
    }

    private static func ports() -> [Port] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var result = [Port]()
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }
            let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            guard location == "External",
                  let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() else { continue }
            var edidRef: Unmanaged<CFData>?
            guard IOAVServiceCopyEDID(service, &edidRef) == kIOReturnSuccess,
                  let edid = edidRef?.takeRetainedValue() as Data?, edid.count >= 128 else { continue }
            result.append(Port(monitor: monitorID(from: [UInt8](edid)), service: service))
        }
        return result
    }

    static func monitorID(from edid: [UInt8]) -> MonitorID {
        var name = "Display"
        for offset in stride(from: 54, to: 126, by: 18) where edid[offset] == 0 && edid[offset + 3] == 0xFC {
            name = String(decoding: edid[(offset + 5)..<(offset + 18)], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return MonitorID(
            vendor: UInt32(edid[8]) << 8 | UInt32(edid[9]),
            model: UInt32(edid[10]) | UInt32(edid[11]) << 8,
            serial: UInt32(edid[12]) | UInt32(edid[13]) << 8 | UInt32(edid[14]) << 16 | UInt32(edid[15]) << 24,
            name: name
        )
    }

    /// Length byte first and the checksum last, which covers the bus addresses too.
    static func packet(for body: [UInt8]) -> [UInt8] {
        var packet = [UInt8(0x80 | body.count)] + body
        packet.append(packet.reduce(0x6E ^ 0x51) { $0 ^ $1 })
        return packet
    }

    /// The value in a reply to a VCP read, nil when it isn't a good answer for that code.
    static func value(fromReply reply: [UInt8], code: UInt8) -> Int? {
        guard reply.count >= 11, reply[2] == 0x02, reply[3] == 0, reply[4] == code,
              reply[0..<10].reduce(0x50, ^) == reply[10] else { return nil }
        return Int(reply[8]) << 8 | Int(reply[9])
    }

    private static func send(_ body: [UInt8], to service: CFTypeRef) -> Bool {
        var packet = packet(for: body)
        return packet.withUnsafeMutableBytes {
            IOAVServiceWriteI2C(service, 0x37, 0x51, $0.baseAddress!, UInt32($0.count))
        } == kIOReturnSuccess
    }

    private static func read(_ code: UInt8, service: CFTypeRef) -> Int? {
        for attempt in 0..<4 {
            if attempt > 0 { usleep(60_000) }
            guard send([0x01, code], to: service) else { continue }
            usleep(50_000)
            var reply = [UInt8](repeating: 0, count: 12)
            let status = reply.withUnsafeMutableBytes { IOAVServiceReadI2C(service, 0x37, 0x51, $0.baseAddress!, 12) }
            guard status == kIOReturnSuccess, let value = value(fromReply: reply, code: code) else { continue }
            return value
        }
        return nil
    }
}

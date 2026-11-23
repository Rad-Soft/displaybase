//
//  RemoteComputer.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import Foundation

/// Asks the other computer things over SSH using your own ~/.ssh/config, so aliases and keys just work.
enum RemoteComputer {
    private struct Output: Sendable {
        let status: Int32
        let text: String
    }

    struct Target: Equatable {
        var hostname: String
        var port: String
        var proxied: Bool
    }

    private final class ProcessBox: @unchecked Sendable {
        let process = Process()
    }

    static func isReachable(host: String) async -> Bool {
        guard let target = await resolve(host) else { return false }
        // a jump host means the port can't be tried directly
        if target.proxied { return await ssh(host, "exit")?.status == 0 }
        return await run("/usr/bin/nc", ["-z", "-G", "2", target.hostname, target.port], timeout: 4)?.status == 0
    }

    /// nil means it couldn't be asked, which is different from "it doesn't have the device".
    static func has(_ device: USBDeviceID, host: String, system: RemoteSystem) async -> Bool? {
        guard let output = await ssh(host, system.listCommand), output.status == 0 else { return nil }
        return system.lists(device, in: output.text)
    }

    static func canRun(host: String, system: RemoteSystem) async -> Bool {
        await ssh(host, system.listCommand)?.status == 0
    }

    // ssh reads a leading dash as an option
    static func isSafe(_ host: String) -> Bool {
        !host.isEmpty && !host.hasPrefix("-") && !host.contains(where: \.isWhitespace)
    }

    private static func ssh(_ host: String, _ command: String) async -> Output? {
        guard isSafe(host) else { return nil }
        return await run("/usr/bin/ssh", ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", host, command], timeout: 10)
    }

    private static func resolve(_ host: String) async -> Target? {
        guard isSafe(host), let output = await run("/usr/bin/ssh", ["-G", host], timeout: 4), output.status == 0 else { return nil }
        return target(from: output.text, host: host)
    }

    /// Where `ssh -G` says a host is, and whether getting there goes through a jump host.
    static func target(from config: String, host: String) -> Target {
        var target = Target(hostname: host, port: "22", proxied: false)
        for line in config.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "hostname" { target.hostname = parts[1] }
            if parts[0] == "port" { target.port = parts[1] }
            if parts[0] == "proxyjump" || parts[0] == "proxycommand", parts[1] != "none" { target.proxied = true }
        }
        return target
    }

    private static func run(_ path: String, _ arguments: [String], timeout: TimeInterval) async -> Output? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let box = ProcessBox()
                let pipe = Pipe()
                box.process.executableURL = URL(fileURLWithPath: path)
                box.process.arguments = arguments
                box.process.standardOutput = pipe
                box.process.standardError = FileHandle.nullDevice
                box.process.standardInput = FileHandle.nullDevice
                do {
                    try box.process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let watchdog = DispatchWorkItem { if box.process.isRunning { box.process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
                // read before waiting, the device list is bigger than the pipe buffer
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                box.process.waitUntilExit()
                watchdog.cancel()
                continuation.resume(returning: Output(status: box.process.terminationStatus, text: String(decoding: data, as: UTF8.self)))
            }
        }
    }
}

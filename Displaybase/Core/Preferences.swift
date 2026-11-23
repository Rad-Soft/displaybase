//
//  Preferences.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    var screens: [DeskScreen] { didSet { store(screens, "screens") } }
    /// What the other computer is called in the app.
    var pcName: String { didSet { defaults.set(pcName, forKey: "pcName") } }
    /// Empty when there's nothing to ask over SSH.
    var remoteHost: String { didSet { defaults.set(remoteHost, forKey: "remoteHost") } }
    var remoteSystem: RemoteSystem { didSet { defaults.set(remoteSystem.rawValue, forKey: "remoteSystem") } }
    var followSwitch: Bool { didSet { defaults.set(followSwitch, forKey: "followSwitch") } }
    /// Off by default so switching back can borrow the keyboard without giving up the other computer's screen.
    var switchBackTakesBack: Bool { didSet { defaults.set(switchBackTakesBack, forKey: "switchBackTakesBack") } }
    /// Optional screens go along too.
    var everyScreen: Bool { didSet { defaults.set(everyScreen, forKey: "everyScreen") } }
    var switchDevice: USBDeviceID? { didSet { store(switchDevice, "switchDevice") } }
    var shortcut: Shortcut { didSet { store(shortcut, "shortcut") } }
    var handover: Handover? { didSet { store(handover, "handover") } }
    /// Lets displaybase:// links work. Off by default, since a web page can open one too.
    var allowLinks: Bool { didSet { defaults.set(allowLinks, forKey: "allowLinks") } }
    var setupDone: Bool { didSet { defaults.set(setupDone, forKey: "setupDone") } }

    var hasRemote: Bool { !remoteHost.isEmpty }
    var hasOptional: Bool { screens.contains { $0.role == .optional } }
    var pcLabel: String { pcName.isEmpty ? "the other computer" : pcName }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["followSwitch": true])
        screens = Self.load("screens", from: defaults) ?? []
        pcName = defaults.string(forKey: "pcName") ?? "PC"
        remoteHost = defaults.string(forKey: "remoteHost") ?? ""
        remoteSystem = defaults.string(forKey: "remoteSystem").flatMap(RemoteSystem.init) ?? .windows
        followSwitch = defaults.bool(forKey: "followSwitch")
        switchBackTakesBack = defaults.bool(forKey: "switchBackTakesBack")
        everyScreen = defaults.bool(forKey: "everyScreen")
        switchDevice = Self.load("switchDevice", from: defaults)
        shortcut = Self.load("shortcut", from: defaults) ?? .standard
        handover = Self.load("handover", from: defaults)
        allowLinks = defaults.bool(forKey: "allowLinks")
        setupDone = defaults.bool(forKey: "setupDone")
    }

    func screen(_ monitor: MonitorID) -> DeskScreen? {
        screens.first { $0.monitor == monitor }
    }

    func update(_ monitor: MonitorID, _ change: (inout DeskScreen) -> Void) {
        guard let index = screens.firstIndex(where: { $0.monitor == monitor }) else { return }
        change(&screens[index])
    }

    private func store<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func load<T: Decodable>(_ key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

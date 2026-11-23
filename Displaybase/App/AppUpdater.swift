//
//  AppUpdater.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class AppUpdater {
    private(set) var canCheck = false
    private(set) var availableVersion: String?
    let isEnabled = CodeSignature.isDeveloperID
    var checksAutomatically: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private let lifecycle: UpdateLifecycle
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init(prepareForRelaunch: @escaping @MainActor () async -> Void) {
        lifecycle = UpdateLifecycle(prepareForRelaunch: prepareForRelaunch)
        controller = SPUStandardUpdaterController(startingUpdater: isEnabled, updaterDelegate: lifecycle, userDriverDelegate: nil)
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        lifecycle.updateFound = { [weak self] version in self?.availableVersion = version }
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let value = change.newValue ?? false
            Task { @MainActor in self?.canCheck = value }
        }
    }

    func check() {
        controller.checkForUpdates(nil)
    }
}

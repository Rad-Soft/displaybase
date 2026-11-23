//
//  UpdateLifecycle.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation
import Sparkle

@MainActor
final class UpdateLifecycle: NSObject, SPUUpdaterDelegate {
    var updateFound: ((String) -> Void)?

    private let prepareForRelaunch: @MainActor () async -> Void
    private var install: (() -> Void)?

    init(prepareForRelaunch: @escaping @MainActor () async -> Void) {
        self.prepareForRelaunch = prepareForRelaunch
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateFound?(item.displayVersionString)
    }

    // screens come home first, so a relaunch never strands one
    func updater(
        _ updater: SPUUpdater,
        shouldPostponeRelaunchForUpdate item: SUAppcastItem,
        untilInvokingBlock installHandler: @escaping () -> Void
    ) -> Bool {
        guard install == nil else { return true }
        install = installHandler
        Task {
            await prepareForRelaunch()
            install?()
            install = nil
        }
        return true
    }
}

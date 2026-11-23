//
//  AppDelegate.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller: DeskController
    let updater: AppUpdater
    private let setup = SetupWindow()

    override init() {
        let controller = DeskController(prefs: Preferences())
        self.controller = controller
        updater = AppUpdater { await controller.comeHome("updating") }
        super.init()
        controller.showSetup = { [weak self] in self?.showSetup() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        if !controller.prefs.setupDone { showSetup() }
    }

    func showSetup() {
        setup.show(controller)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(controller.handle)
    }

    // quitting now would strand a monitor on the other computer with macOS still pointed elsewhere
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard controller.busy || controller.prefs.handover != nil else { return .terminateNow }
        Task {
            await controller.comeHome("quit")
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

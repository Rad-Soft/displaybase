//
//  SetupWindow.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

@MainActor
final class SetupWindow {
    private var window: NSWindow?

    func show(_ controller: DeskController) {
        if window == nil {
            let view = SetupView { [weak self] in
                controller.prefs.setupDone = true
                self?.window?.close()
            }
            let hosting = NSHostingController(rootView: view.environment(controller))
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.setContentSize(NSSize(width: 800, height: 520))
            window.title = "Set up Displaybase"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

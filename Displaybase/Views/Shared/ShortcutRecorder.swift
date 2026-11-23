//
//  ShortcutRecorder.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ShortcutRecorder: View {
    @Environment(DeskController.self) private var controller
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button(monitor == nil ? controller.prefs.shortcut.label : "Press the new shortcut…", action: toggle)
                .accessibilityLabel("Shortcut, \(controller.prefs.shortcut.label)")
            if controller.shortcutTaken {
                Text("Another app uses this one.")
                    .font(.caption)
                    .foregroundStyle(Color(.warn))
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        if monitor == nil {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        controller.pauseShortcut()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // escape backs out
            if event.keyCode == 53 {
                stop()
            } else if let shortcut = Shortcut(event: event) {
                controller.prefs.shortcut = shortcut
                stop()
            }
            return nil
        }
    }

    private func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        controller.shortcutChanged()
    }
}

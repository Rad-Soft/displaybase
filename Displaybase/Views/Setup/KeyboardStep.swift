//
//  KeyboardStep.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct KeyboardStep: View {
    @Environment(DeskController.self) private var controller
    @State private var finder = SwitchFinder()

    var body: some View {
        @Bindable var prefs = controller.prefs

        SetupForm(
            title: "Share a keyboard?",
            detail: """
                If a USB switch moves your keyboard between computers, your screens can move with it. \
                Press its button now, then press it again to come back here.
                """
        ) {
            Section {
                if choices.isEmpty {
                    Label {
                        Text("Waiting for something to move…")
                    } icon: {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else {
                    Picker("Watch this", selection: $prefs.switchDevice) {
                        Text("Nothing").tag(USBDeviceID?.none)
                        ForEach(choices) { Text($0.name).tag(Optional($0)) }
                    }
                    Toggle("Hand over when it leaves the Mac", isOn: $prefs.followSwitch)
                    Toggle("Bring everything back when it returns", isOn: $prefs.switchBackTakesBack)
                }
            } footer: {
                Text("No switch? Keep going. You can hand over from the menu bar or with a shortcut.")
            }
        }
        .task { await finder.watch() }
        .onChange(of: finder.found) { pick() }
        .onChange(of: prefs.switchDevice) { controller.watchSwitchDevice() }
    }

    private var choices: [USBDeviceID] {
        guard let saved = controller.prefs.switchDevice, !finder.found.contains(saved) else { return finder.found }
        return finder.found + [saved]
    }

    private func pick() {
        if controller.prefs.switchDevice == nil { controller.prefs.switchDevice = finder.best }
    }
}

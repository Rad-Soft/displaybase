//
//  PermissionsStep.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct PermissionsStep: View {
    @Environment(DeskController.self) private var controller

    var body: some View {
        SetupForm(title: "A few extras", detail: "All optional. You can change them later in Settings.") {
            Section {
                LabeledContent {
                    if controller.windowsAllowed {
                        Label("On", systemImage: "checkmark.circle.fill")
                    } else {
                        Button("Allow…", action: controller.allowWindowRestore)
                    }
                } label: {
                    Text("Put windows back")
                    Text("Needs Accessibility, to move windows to where they were.")
                }
                LabeledContent {
                    Button("Allow…", action: Notifier.requestAccess)
                } label: {
                    Text("Warnings")
                    Text("A notification if your switch goes missing.")
                }
                LoginToggle()
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if controller.prefs.hasRemote {
                        Text("macOS will also ask about your local network, to reach \(controller.prefs.pcLabel) over SSH.")
                    }
                    Text("Displaybase never records your screen or what you type, and there's no account.")
                }
            }
        }
        .task { await watchAccess() }
    }

    private func watchAccess() async {
        while !Task.isCancelled {
            controller.windowsAllowed = WindowKeeper.isTrusted
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

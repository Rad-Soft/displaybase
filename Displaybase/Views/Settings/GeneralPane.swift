//
//  GeneralPane.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct GeneralPane: View {
    @Environment(DeskController.self) private var controller

    var body: some View {
        @Bindable var prefs = controller.prefs

        Form {
            Section {
                LabeledContent("Shortcut") { ShortcutRecorder() }
                LoginToggle()
                Toggle("Allow displaybase:// links", isOn: $prefs.allowLinks)
                LabeledContent("Put windows back") {
                    if controller.windowsAllowed {
                        Text("On")
                    } else {
                        Button("Allow…", action: controller.allowWindowRestore)
                    }
                }
            }
            UpdatesSection()
            Section {
                Button("Run setup again…", action: controller.showSetup)
                Link("displaybase.radsoft.tech", destination: URL(string: "https://displaybase.radsoft.tech")!)
            }
        }
        .formStyle(.grouped)
    }
}

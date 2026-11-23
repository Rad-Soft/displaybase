//
//  ComputerPane.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ComputerPane: View {
    @Environment(DeskController.self) private var controller

    var body: some View {
        @Bindable var prefs = controller.prefs

        Form {
            Section {
                TextField("Name", text: $prefs.pcName, prompt: Text("PC"))
            }
            Section {
                TextField("SSH host", text: $prefs.remoteHost, prompt: Text("Optional"))
                Picker("It runs", selection: $prefs.remoteSystem) {
                    ForEach(RemoteSystem.allCases) { Text($0.label).tag($0) }
                }
                RemoteCheck()
            } header: {
                Text("Check on it over SSH")
            } footer: {
                Text("""
                    Optional. Displaybase asks whether your keyboard really landed there before it gives a screen away, \
                    and takes the screens back if the computer goes offline. It uses your own SSH config and keys.
                    """)
            }
        }
        .formStyle(.grouped)
    }
}

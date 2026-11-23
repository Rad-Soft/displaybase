//
//  ComputerStep.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ComputerStep: View {
    @Environment(DeskController.self) private var controller

    var body: some View {
        @Bindable var prefs = controller.prefs

        SetupForm(
            title: "The other computer",
            detail: "If you can SSH into it, Displaybase makes sure your keyboard really landed there before it gives a screen away."
        ) {
            Section {
                TextField("Name", text: $prefs.pcName, prompt: Text("PC"))
            }
            Section {
                TextField("SSH host", text: $prefs.remoteHost, prompt: Text("Optional"))
                if prefs.hasRemote {
                    Picker("It runs", selection: $prefs.remoteSystem) {
                        ForEach(RemoteSystem.allCases) { Text($0.label).tag($0) }
                    }
                    RemoteCheck()
                }
            }
        }
    }
}

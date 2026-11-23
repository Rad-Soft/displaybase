//
//  UpdatesSection.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct UpdatesSection: View {
    @Environment(AppUpdater.self) private var updater

    var body: some View {
        @Bindable var updater = updater

        Section("Updates") {
            if updater.isEnabled {
                Toggle("Check for updates automatically", isOn: $updater.checksAutomatically)
                LabeledContent("Version \(version)") {
                    Button("Check now", action: updater.check)
                        .disabled(!updater.canCheck)
                }
            } else {
                LabeledContent("Version \(version)", value: "Built from source")
            }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

//
//  MenuPanel.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct MenuPanel: View {
    @Environment(DeskController.self) private var controller

    var body: some View {
        @Bindable var prefs = controller.prefs

        VStack(alignment: .leading, spacing: 14) {
            MenuHeader()
            DeskMap(items: controller.desk, pcName: prefs.pcLabel)
                .frame(height: 168)
            HandOverButton()

            if let note = controller.note {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(Color(.warn))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                if prefs.hasOptional {
                    Toggle("Give \(prefs.pcLabel) every screen", isOn: $prefs.everyScreen)
                        .disabled(controller.busy)
                }
                if prefs.switchDevice != nil {
                    Toggle("Follow my USB switch", isOn: $prefs.followSwitch)
                }
            }
            .toggleStyle(BrandSwitchStyle())

            MenuStatus()
            UpdateBanner()
            Divider()
            MenuFooter()
        }
        .padding(16)
        .frame(width: 330)
        .onChange(of: prefs.everyScreen) { Task { await controller.resyncOptional() } }
    }
}

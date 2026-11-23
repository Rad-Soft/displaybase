//
//  MenuFooter.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct MenuFooter: View {
    @Environment(DeskController.self) private var controller
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack {
            Button("Settings…", action: settings)
            Button("Setup…", action: controller.showSetup)
            Spacer()
            Button("Quit", action: quit)
        }
        .buttonStyle(.borderless)
    }

    private func settings() {
        NSApp.activate()
        openSettings()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

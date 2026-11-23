//
//  ScreensPane.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ScreensPane: View {
    @Environment(DeskController.self) private var controller

    var body: some View {
        @Bindable var prefs = controller.prefs

        Form {
            if prefs.screens.isEmpty {
                ContentUnavailableView(
                    "No monitors answered",
                    systemImage: "display.trianglebadge.exclamationmark",
                    description: Text("Turn on DDC/CI in the monitor's own menu, then come back.")
                )
            }
            ForEach($prefs.screens) { $screen in
                ScreenSection(screen: $screen)
            }
        }
        .formStyle(.grouped)
        .task { await controller.findScreens() }
    }
}

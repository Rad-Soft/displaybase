//
//  ScreensStep.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ScreensStep: View {
    @Environment(DeskController.self) private var controller
    @State private var looked = false

    var body: some View {
        @Bindable var prefs = controller.prefs

        SetupForm(
            title: "Which screens move?",
            detail: "Choose what happens to each monitor when the other computer takes over."
        ) {
            if let note = controller.note {
                Label(note, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color(.warn))
            }
            if prefs.screens.isEmpty, looked {
                ContentUnavailableView(
                    "No monitors answered",
                    systemImage: "display.trianglebadge.exclamationmark",
                    description: Text("Turn on DDC/CI in the monitor's own menu, then go back and try again.")
                )
            }
            ForEach($prefs.screens) { $screen in
                ScreenSetupSection(screen: $screen)
            }
        }
        .task { await look() }
    }

    private func look() async {
        await controller.findScreens()
        looked = true
    }
}

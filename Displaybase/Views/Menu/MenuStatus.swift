//
//  MenuStatus.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct MenuStatus: View {
    @Environment(DeskController.self) private var controller

    var body: some View {
        VStack(spacing: 6) {
            if let device = controller.prefs.switchDevice {
                StatusRow(label: device.name) { Text(spot) }
            }
            if controller.prefs.hasRemote {
                StatusRow(label: controller.prefs.pcLabel) { Text(online) }
            }
            if !controller.windowsAllowed {
                StatusRow(label: "Windows") {
                    Button("Let it put them back…", action: controller.allowWindowRestore)
                        .buttonStyle(.link)
                }
            }
        }
    }

    private var spot: String {
        switch controller.switchSpot {
        case .mac: "On the Mac"
        case .pc: "On \(controller.prefs.pcLabel)"
        case .elsewhere: "On neither computer"
        case .unknown: "Checking…"
        }
    }

    private var online: String {
        switch controller.pcOnline {
        case true?: "Online"
        case false?: "Offline"
        case nil: "Checking…"
        }
    }
}

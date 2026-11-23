//
//  HandOverButton.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct HandOverButton: View {
    @Environment(DeskController.self) private var controller

    private var here: Bool { controller.mode == .mac }

    var body: some View {
        Button(action: controller.toggle) {
            HStack {
                Text(here ? "Hand over to \(controller.prefs.pcLabel)" : "Bring everything back")
                Spacer()
                Text(controller.prefs.shortcut.label)
                    .opacity(0.75)
            }
        }
        .buttonStyle(BrandButtonStyle(fills: true))
        .disabled(controller.busy)
    }
}

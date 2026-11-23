//
//  RolePicker.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct RolePicker: View {
    @Environment(DeskController.self) private var controller
    @Binding var screen: DeskScreen

    var body: some View {
        Picker("When you hand over", selection: $screen.role) {
            Text("Goes to \(controller.prefs.pcLabel)").tag(ScreenRole.goes)
            Text("Goes if you give every screen").tag(ScreenRole.optional)
            Text("Stays on the Mac").tag(ScreenRole.stays)
        }
        .disabled(controller.mode == .pc)
    }
}

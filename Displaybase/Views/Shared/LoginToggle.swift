//
//  LoginToggle.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import ServiceManagement
import SwiftUI

struct LoginToggle: View {
    @State private var isOn = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Open at login", isOn: $isOn)
            .onChange(of: isOn) { apply() }
    }

    private func apply() {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            isOn = SMAppService.mainApp.status == .enabled
        }
    }
}

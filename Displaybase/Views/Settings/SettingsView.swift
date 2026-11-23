//
//  SettingsView.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Screens", systemImage: "display.2") { ScreensPane() }
            Tab("Switch", systemImage: "cable.connector") { SwitchPane() }
            Tab("Computer", systemImage: "pc") { ComputerPane() }
            Tab("General", systemImage: "gearshape") { GeneralPane() }
        }
        .frame(width: 500, height: 430)
        .tint(Color(.brand))
        .toggleStyle(BrandSwitchStyle())
    }
}

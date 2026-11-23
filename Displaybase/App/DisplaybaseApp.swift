//
//  DisplaybaseApp.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/9/26.
//

import SwiftUI

@main
struct DisplaybaseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environment(delegate.controller)
                .environment(delegate.updater)
        } label: {
            MenuBarIcon(controller: delegate.controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(delegate.controller)
                .environment(delegate.updater)
        }
    }
}

//
//  SwitchPane.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct SwitchPane: View {
    @Environment(DeskController.self) private var controller
    @State private var devices: [USBDeviceID] = []

    var body: some View {
        @Bindable var prefs = controller.prefs

        Form {
            Section {
                Picker("Device on the switch", selection: $prefs.switchDevice) {
                    Text("I don't use one").tag(USBDeviceID?.none)
                    ForEach(choices) { Text($0.name).tag(Optional($0)) }
                }
            } footer: {
                Text("Pick something that's always plugged into the switch, like the keyboard. Displaybase watches it come and go.")
            }
            Section {
                Toggle("Hand over when it leaves the Mac", isOn: $prefs.followSwitch)
                Toggle("Bring everything back when it returns", isOn: $prefs.switchBackTakesBack)
            } footer: {
                Text("With the second one off, switching back only borrows the keyboard, and \(prefs.pcLabel) keeps its screen.")
            }
            .disabled(prefs.switchDevice == nil)
        }
        .formStyle(.grouped)
        .onAppear { devices = USBWatcher.connectedDevices() }
        .onChange(of: prefs.switchDevice) { controller.watchSwitchDevice() }
    }

    private var choices: [USBDeviceID] {
        guard let saved = controller.prefs.switchDevice, !devices.contains(saved) else { return devices }
        return devices + [saved]
    }
}

//
//  ScreenSection.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ScreenSection: View {
    @Environment(DeskController.self) private var controller
    @Binding var screen: DeskScreen
    @State private var inputs = InputSource.common

    var body: some View {
        Section(screen.monitor.name) {
            RolePicker(screen: $screen)
            Group {
                if screen.role != .stays {
                    Picker("\(controller.prefs.pcLabel)'s input", selection: $screen.pcInput) {
                        ForEach(choices(screen.pcInput), id: \.self) { Text(InputSource.name($0)).tag($0) }
                    }
                    Picker("Mac's input", selection: $screen.macInput) {
                        Text("Learn it").tag(Int?.none)
                        ForEach(choices(screen.macInput), id: \.self) { Text(InputSource.name($0)).tag(Optional($0)) }
                    }
                }
            }
            .disabled(controller.mode == .pc)
            Picker("Keep it rotated", selection: $screen.rotation) {
                Text("Leave to macOS").tag(Int?.none)
                Text("Standard").tag(Int?.some(0))
                Text("90°").tag(Int?.some(90))
                Text("180°").tag(Int?.some(180))
                Text("270°").tag(Int?.some(270))
            }
        }
        .task { await load() }
        .onChange(of: screen.rotation) { controller.holdRotation() }
    }

    private func load() async {
        let monitor = screen.monitor
        let found = await Task.detached(operation: { DDC.inputs(of: monitor) }).value
        if !found.isEmpty { inputs = found }
    }

    // keep the saved choice selectable even when the monitor doesn't list it
    private func choices(_ value: Int?) -> [Int] {
        guard let value, !inputs.contains(value) else { return inputs }
        return inputs + [value]
    }
}

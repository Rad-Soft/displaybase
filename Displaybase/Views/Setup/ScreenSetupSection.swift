//
//  ScreenSetupSection.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ScreenSetupSection: View {
    @Environment(DeskController.self) private var controller
    @Binding var screen: DeskScreen
    @State private var inputs = InputSource.common
    @State private var trying = false

    var body: some View {
        Section(screen.monitor.name) {
            RolePicker(screen: $screen)
            if screen.role != .stays {
                Picker("\(controller.prefs.pcLabel)'s input", selection: $screen.pcInput) {
                    ForEach(inputs.contains(screen.pcInput) ? inputs : inputs + [screen.pcInput], id: \.self) {
                        Text(InputSource.name($0)).tag($0)
                    }
                }
                LabeledContent("See it there for five seconds") {
                    Button(trying ? "Coming back…" : "Try it", action: tryIt)
                        .disabled(controller.busy)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        let monitor = screen.monitor
        let found = await Task.detached(operation: { DDC.inputs(of: monitor) }).value
        if !found.isEmpty { inputs = found }
    }

    private func tryIt() {
        trying = true
        Task {
            await controller.preview(screen)
            trying = false
        }
    }
}

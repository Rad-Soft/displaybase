//
//  RemoteCheck.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct RemoteCheck: View {
    enum Result {
        case idle
        case checking
        case works
        case unreachable
        case refused
    }

    @Environment(DeskController.self) private var controller
    @State private var result = Result.idle

    var body: some View {
        LabeledContent {
            Button("Check", action: check)
                .disabled(!controller.prefs.hasRemote || result == .checking)
        } label: {
            switch result {
            case .idle: Text("Connection")
            case .checking: Text("Checking…")
            case .works: Label("It answers", systemImage: "checkmark.circle.fill")
            case .unreachable: Label("Can't reach it", systemImage: "xmark.circle")
            case .refused: Label("Reachable, but sign-in or the command failed", systemImage: "exclamationmark.triangle")
            }
        }
        .onChange(of: controller.prefs.remoteHost) { result = .idle }
        .onChange(of: controller.prefs.remoteSystem) { result = .idle }
    }

    private func check() {
        result = .checking
        let host = controller.prefs.remoteHost
        let system = controller.prefs.remoteSystem
        Task {
            guard await RemoteComputer.isReachable(host: host) else {
                result = .unreachable
                return
            }
            result = await RemoteComputer.canRun(host: host, system: system) ? .works : .refused
        }
    }
}

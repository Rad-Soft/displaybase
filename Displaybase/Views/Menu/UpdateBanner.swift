//
//  UpdateBanner.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct UpdateBanner: View {
    @Environment(AppUpdater.self) private var updater

    var body: some View {
        if let version = updater.availableVersion {
            HStack {
                Label("Displaybase \(version) is out", systemImage: "arrow.down.circle")
                Spacer()
                Button("Update…", action: updater.check)
                    .buttonStyle(.link)
            }
            .font(.callout)
        }
    }
}

//
//  MenuHeader.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct MenuHeader: View {
    @Environment(DeskController.self) private var controller

    private var away: Int { controller.prefs.handover?.away.count ?? 0 }

    var body: some View {
        HStack(spacing: 9) {
            BrandMark()
                .frame(height: 18)
            Text("Displaybase")
                .font(.headline)
            Spacer()
            if controller.busy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Working")
            }
            Text(away == 0 ? "Everything's on the Mac" : "\(controller.prefs.pcLabel) has ^[\(away) screen](inflect: true)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

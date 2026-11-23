//
//  DeskPreview.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

/// The desk flipping between now and handed over, so the choices on the right show what they do.
struct DeskPreview: View {
    @Environment(DeskController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var handedOver = true

    var body: some View {
        VStack(spacing: 14) {
            DeskMap(items: items, pcName: controller.prefs.pcLabel)
                .frame(height: 210)
            Text(handedOver ? "After you hand over" : "Right now")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .task { await flip() }
    }

    private var items: [DeskItem] {
        controller.desk.map { item in
            let role = controller.prefs.screen(item.monitor)?.role ?? .stays
            let moves = role == .goes || (role == .optional && controller.prefs.everyScreen)
            return DeskItem(monitor: item.monitor, frame: item.frame, isBuiltin: item.isBuiltin, onPC: handedOver && moves)
        }
    }

    private func flip() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            handedOver.toggle()
        }
    }
}

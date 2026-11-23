//
//  DeskMap.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct DeskMap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let items: [DeskItem]
    let pcName: String

    var body: some View {
        DeskLayout(frames: items.map(\.frame)) {
            ForEach(items) { item in
                DeskScreenTile(item: item, pcName: pcName)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.5), value: items)
        .padding(14)
        .background(Color(.desk), in: .rect(cornerRadius: 12))
    }
}

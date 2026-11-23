//
//  DeskScreenTile.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct DeskScreenTile: View {
    let item: DeskItem
    let pcName: String

    private var holder: String { item.onPC ? pcName : "Mac" }
    private var symbol: String { item.onPC ? "pc" : "laptopcomputer" }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(item.onPC ? Color(.clay) : Color(.sky))
            .overlay {
                ViewThatFits {
                    VStack(spacing: 3) {
                        Image(systemName: symbol)
                        Text(item.isBuiltin ? "Laptop" : item.monitor.name)
                            .font(.caption)
                            .bold()
                        Text(holder)
                            .font(.caption)
                    }
                    VStack(spacing: 2) {
                        Image(systemName: symbol)
                        Text(holder)
                            .font(.caption)
                    }
                    Image(systemName: symbol)
                        .font(.title3)
                }
                .lineLimit(1)
                .foregroundStyle(Color(.deep))
                .padding(4)
                .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityElement()
            .accessibilityLabel("\(item.isBuiltin ? "Laptop screen" : item.monitor.name) is on \(item.onPC ? pcName : "the Mac")")
    }
}

//
//  BrandMark.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

/// The split D: the left half is the Mac's screen, the right half is the one that moves.
struct BrandMark: View {
    var mac = Color(.brand)
    var pc = Color(.brand)

    var body: some View {
        ZStack {
            BrandHalf(side: .left).fill(mac)
            BrandHalf(side: .right).fill(pc)
        }
        .aspectRatio(49 / 48, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

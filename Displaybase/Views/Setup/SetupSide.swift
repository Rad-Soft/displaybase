//
//  SetupSide.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct SetupSide: View {
    let step: SetupStep

    var body: some View {
        ZStack {
            Color(.desk)
            if step == .welcome {
                BrandMark()
                    .frame(height: 120)
            } else {
                DeskPreview()
                    .padding(.horizontal, 10)
            }
        }
    }
}

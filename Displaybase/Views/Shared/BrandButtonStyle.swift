//
//  BrandButtonStyle.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct BrandButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fills = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .bold()
            .foregroundStyle(Color(.onBrand))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: fills ? .infinity : nil)
            .background(Color(.brand), in: .rect(cornerRadius: 10))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(.rect)
    }
}

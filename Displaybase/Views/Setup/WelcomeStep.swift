//
//  WelcomeStep.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("One desk,\ntwo computers.")
                .font(.system(.largeTitle, weight: .bold))
            Text("Displaybase hands a monitor to your other computer, tidies your Mac onto the screen it keeps, and puts everything back when you're done.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 44)
    }
}

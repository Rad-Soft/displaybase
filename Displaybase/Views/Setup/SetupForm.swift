//
//  SetupForm.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct SetupForm<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title)
                    .bold()
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            Form { content }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .padding(.horizontal, 10)
        }
        .padding(.top, 44)
    }
}

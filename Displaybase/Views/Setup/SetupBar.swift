//
//  SetupBar.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct SetupBar: View {
    @Environment(DeskController.self) private var controller
    @Binding var step: SetupStep
    let finish: () -> Void

    var body: some View {
        HStack {
            Button("Back", action: back)
                .buttonStyle(.borderless)
                .opacity(step.previous == nil ? 0 : 1)
                .disabled(step.previous == nil)
            Spacer()
            HStack(spacing: 6) {
                ForEach(SetupStep.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color(.brand) : Color.secondary.opacity(0.25))
                        .frame(width: item == step ? 20 : 8, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(SetupStep.allCases.count)")
            Spacer()
            Button(step == .welcome ? "Get started" : step.next == nil ? "Finish" : "Continue", action: forward)
                .buttonStyle(BrandButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(controller.busy)
        }
        .padding(20)
    }

    private func back() {
        if let previous = step.previous { step = previous }
    }

    private func forward() {
        if let next = step.next {
            step = next
        } else {
            finish()
        }
    }
}

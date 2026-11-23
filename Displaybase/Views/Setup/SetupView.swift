//
//  SetupView.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct SetupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: SetupStep
    private let finish: () -> Void

    init(step: SetupStep = .welcome, finish: @escaping () -> Void) {
        _step = State(initialValue: step)
        self.finish = finish
    }

    var body: some View {
        HStack(spacing: 0) {
            SetupSide(step: step)
                .frame(width: 290)
            VStack(spacing: 0) {
                Group {
                    switch step {
                    case .welcome: WelcomeStep()
                    case .screens: ScreensStep()
                    case .keyboard: KeyboardStep()
                    case .computer: ComputerStep()
                    case .permissions: PermissionsStep()
                    case .ready: ReadyStep()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                SetupBar(step: $step, finish: finish)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .ignoresSafeArea()
        .tint(Color(.brand))
        .toggleStyle(BrandSwitchStyle())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: step)
    }
}

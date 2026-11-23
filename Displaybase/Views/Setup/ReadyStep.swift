//
//  ReadyStep.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct ReadyStep: View {
    var body: some View {
        SetupForm(
            title: "You're set",
            detail: "Displaybase lives in the menu bar. Press the shortcut to hand over, and press it again to bring everything back."
        ) {
            LabeledContent("Shortcut") { ShortcutRecorder() }
        }
    }
}

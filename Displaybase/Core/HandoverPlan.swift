//
//  HandoverPlan.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics

/// Who goes, who stays, and where the menu bar ends up.
struct HandoverPlan {
    struct Leaving {
        let screen: DeskScreen
        let id: CGDirectDisplayID
    }

    let leaving: [Leaving]
    let remaining: [ScreenInfo]
    let home: ScreenInfo
}

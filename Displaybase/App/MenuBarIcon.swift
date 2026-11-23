//
//  MenuBarIcon.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct MenuBarIcon: View {
    let controller: DeskController

    var body: some View {
        Image(icon)
            .accessibilityLabel(away == 0 ? "Displaybase" : "Displaybase, \(controller.prefs.pcLabel) has ^[\(away) screen](inflect: true)")
    }

    private var away: Int { controller.prefs.handover?.away.count ?? 0 }

    // a hollow half is a screen the other computer has
    private var icon: ImageResource {
        if controller.everyScreenAway { return .menuBoth }
        return controller.mode == .pc ? .menuPC : .menuMac
    }
}

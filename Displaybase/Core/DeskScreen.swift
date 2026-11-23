//
//  DeskScreen.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

enum ScreenRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case stays
    case goes
    case optional

    var id: Self { self }
}

struct DeskScreen: Codable, Hashable, Identifiable, Sendable {
    var monitor: MonitorID
    var role = ScreenRole.stays
    var pcInput = 0x0F
    // learned from the monitor, so coming back lands on the Mac's own port
    var macInput: Int?
    // nil leaves it to macOS
    var rotation: Int?

    var id: MonitorID { monitor }
}

extension DeskScreen {
    // a setting saved by another version can miss a key, and shouldn't take the rest with it
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            monitor: try values.decode(MonitorID.self, forKey: .monitor),
            role: try values.decodeIfPresent(ScreenRole.self, forKey: .role) ?? .stays,
            pcInput: try values.decodeIfPresent(Int.self, forKey: .pcInput) ?? 0x0F,
            macInput: try values.decodeIfPresent(Int.self, forKey: .macInput),
            rotation: try values.decodeIfPresent(Int.self, forKey: .rotation)
        )
    }
}

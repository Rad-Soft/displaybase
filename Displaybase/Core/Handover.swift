//
//  Handover.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// What handing over undid, so coming back can put it all right, even after a relaunch.
struct Handover: Codable, Sendable {
    struct Away: Codable, Sendable {
        let monitor: MonitorID
        // set while macOS has the screen turned off
        var display: UInt32?
        var optional = false
        // what it was on before, in case the setting changes while it's away
        var macInput: Int?
    }

    var away: [Away]
    var layout: LayoutSnapshot?
    var keyboardOnPC = false

    func has(_ monitor: MonitorID) -> Bool {
        away.contains { $0.monitor == monitor }
    }

    mutating func setDisplay(_ id: UInt32?, for monitor: MonitorID) {
        guard let index = away.firstIndex(where: { $0.monitor == monitor }) else { return }
        away[index].display = id
    }
}

extension Handover {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            away: try values.decode([Away].self, forKey: .away),
            layout: try values.decodeIfPresent(LayoutSnapshot.self, forKey: .layout),
            keyboardOnPC: try values.decodeIfPresent(Bool.self, forKey: .keyboardOnPC) ?? false
        )
    }
}

extension Handover.Away {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            monitor: try values.decode(MonitorID.self, forKey: .monitor),
            display: try values.decodeIfPresent(UInt32.self, forKey: .display),
            optional: try values.decodeIfPresent(Bool.self, forKey: .optional) ?? false,
            macInput: try values.decodeIfPresent(Int.self, forKey: .macInput)
        )
    }
}

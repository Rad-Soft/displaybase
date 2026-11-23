//
//  EventLog.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

/// Every hardware call the controller makes, in the order it made them.
@MainActor
final class EventLog {
    private(set) var events = [String]()
    var onEvent: ((String) -> Void)?

    func add(_ event: String) {
        events.append(event)
        onEvent?(event)
    }

    func clear() {
        events.removeAll()
    }

    func index(of event: String) -> Int? {
        events.firstIndex(of: event)
    }

    func count(of event: String) -> Int {
        events.filter { $0 == event }.count
    }

    func contains(_ event: String) -> Bool {
        events.contains(event)
    }

    /// True when both happened and the first one came first.
    func happened(_ first: String, before second: String) -> Bool {
        guard let a = index(of: first), let b = index(of: second) else { return false }
        return a < b
    }
}

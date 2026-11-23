//
//  Settle.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Testing

/// Lets spawned tasks run until a condition holds. Nothing here sleeps, so it only takes turns.
@MainActor
func settle(_ what: String, until condition: @MainActor () -> Bool) async {
    for _ in 0..<5000 {
        if condition() { return }
        await Task.yield()
    }
    Issue.record("never settled: \(what)")
}

/// Gives spawned tasks a few turns when there's nothing to wait for but "nothing happened".
@MainActor
func drain() async {
    for _ in 0..<100 { await Task.yield() }
}

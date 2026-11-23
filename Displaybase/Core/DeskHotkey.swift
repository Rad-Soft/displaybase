//
//  DeskHotkey.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Foundation

@MainActor
protocol DeskHotkey: AnyObject {
    var action: () -> Void { get set }
    /// False when another app already has it.
    func register(_ shortcut: Shortcut) -> Bool
    func unregister()
}

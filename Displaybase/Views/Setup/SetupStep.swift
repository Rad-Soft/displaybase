//
//  SetupStep.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

enum SetupStep: Int, CaseIterable {
    case welcome
    case screens
    case keyboard
    case computer
    case permissions
    case ready

    var next: SetupStep? { SetupStep(rawValue: rawValue + 1) }
    var previous: SetupStep? { SetupStep(rawValue: rawValue - 1) }
}

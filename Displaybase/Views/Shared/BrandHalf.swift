//
//  BrandHalf.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

struct BrandHalf: Shape {
    enum Side {
        case left
        case right
    }

    let side: Side

    func path(in rect: CGRect) -> Path {
        let unit = rect.height / 48
        switch side {
        case .left:
            let slab = CGRect(x: rect.minX, y: rect.minY, width: 19.5 * unit, height: rect.height)
            return Path(roundedRect: slab, cornerRadii: RectangleCornerRadii(topLeading: 3 * unit, bottomLeading: 3 * unit))
        case .right:
            var path = Path()
            let edge = rect.minX + 24.5 * unit
            path.move(to: CGPoint(x: edge, y: rect.minY))
            path.addArc(
                center: CGPoint(x: edge + 0.5 * unit, y: rect.midY),
                radius: 24 * unit,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: edge, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

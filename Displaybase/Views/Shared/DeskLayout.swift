//
//  DeskLayout.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import SwiftUI

/// Places each screen where it really sits, scaled to fit.
struct DeskLayout: Layout {
    let frames: [CGRect]
    var gap: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 280, height: 140))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, Self.fit(frames, in: bounds.size, gap: gap)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    static func fit(_ frames: [CGRect], in size: CGSize, gap: CGFloat = 0) -> [CGRect] {
        guard let first = frames.first else { return [] }
        let union = frames.dropFirst().reduce(first) { $0.union($1) }
        guard union.width > 0, union.height > 0 else { return frames.map { _ in .zero } }
        let scale = min(size.width / union.width, size.height / union.height)
        let origin = CGPoint(
            x: (size.width - union.width * scale) / 2 - union.minX * scale,
            y: (size.height - union.height * scale) / 2 - union.minY * scale
        )
        return frames.map {
            CGRect(
                x: origin.x + $0.minX * scale,
                y: origin.y + $0.minY * scale,
                width: $0.width * scale,
                height: $0.height * scale
            )
            .insetBy(dx: gap / 2, dy: gap / 2)
        }
    }
}

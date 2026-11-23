//
//  DeskLayoutTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CoreGraphics
import Testing

struct DeskLayoutTests {
    let box = CGSize(width: 300, height: 100)

    @Test func singleFrameIsCentered() {
        let fitted = DeskLayout.fit([CGRect(x: 500, y: 500, width: 1000, height: 1000)], in: box)
        #expect(fitted == [CGRect(x: 100, y: 0, width: 100, height: 100)])
    }

    @Test func negativeOriginsLandInsideTheBox() {
        let frames = [CGRect(x: -3000, y: -2000, width: 1000, height: 500), CGRect(x: -2000, y: -2000, width: 1000, height: 500)]
        let fitted = DeskLayout.fit(frames, in: CGSize(width: 200, height: 200))
        #expect(fitted[0].minX == 0 && fitted[1].maxX == 200)
        #expect(fitted[0].maxX == fitted[1].minX)
        #expect(fitted[0].midY == 100)
    }

    @Test func gapShrinksEachFrameEvenly() {
        let frames = [CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 0, width: 100, height: 100)]
        let plain = DeskLayout.fit(frames, in: CGSize(width: 200, height: 100))
        let gapped = DeskLayout.fit(frames, in: CGSize(width: 200, height: 100), gap: 10)
        for (a, b) in zip(plain, gapped) {
            #expect(b == a.insetBy(dx: 5, dy: 5))
        }
        #expect(gapped[1].minX - gapped[0].maxX == 10)
    }

    @Test func zeroSizedDeskGivesZeroFrames() {
        let frames = [CGRect(x: 10, y: 10, width: 0, height: 0), CGRect(x: 10, y: 10, width: 0, height: 50)]
        #expect(DeskLayout.fit(frames, in: box) == [.zero, .zero])
        #expect(DeskLayout.fit([.zero], in: box) == [.zero])
    }

    @Test func zeroSizedBoxCollapses() {
        let fitted = DeskLayout.fit([CGRect(x: 0, y: 0, width: 100, height: 50)], in: .zero)
        #expect(fitted[0].width == 0 && fitted[0].height == 0)
    }

    @Test("aspect ratio survives any box", arguments: [
        CGSize(width: 300, height: 100), CGSize(width: 100, height: 300), CGSize(width: 50, height: 50),
    ])
    func aspect(size: CGSize) {
        let frame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let fitted = DeskLayout.fit([frame], in: size)[0]
        #expect(abs(fitted.width / fitted.height - 2560.0 / 1440.0) < 0.0001)
        #expect(fitted.width <= size.width + 0.001 && fitted.height <= size.height + 0.001)
    }

    @Test func relativePositionsHold() {
        let frames = [CGRect(x: 0, y: 0, width: 1000, height: 1000), CGRect(x: 1000, y: 500, width: 1000, height: 500)]
        let fitted = DeskLayout.fit(frames, in: CGSize(width: 400, height: 200))
        #expect(fitted.count == 2)
        #expect(abs(fitted[1].minX - fitted[0].maxX) < 0.001)
        #expect(abs(fitted[1].minY - fitted[0].midY) < 0.001)
    }
}

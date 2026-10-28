//
//  ColorWindowPlacementTests.swift
//  QuickRecorderTests
//
//  Where the custom background colour window sits beside the bubble that opened it (#117).
//

import Foundation
import Testing

@Suite("The custom colour window's place")
struct ColorWindowPlacementTests {
    let visible = CGRect(x: 0, y: 0, width: 1710, height: 1073)
    let size = CGSize(width: 320, height: 252)
    let bubble = CGRect(x: 540, y: 300, width: 248, height: 180)

    @Test func rightOfTheBubble() {
        let frame = ColorWindowPlacement.frame(bubble: bubble, size: size, visible: visible)
        #expect(frame.minX == bubble.maxX + 16)
        #expect(frame.minY == bubble.minY)
    }

    @Test func flipsLeftWhenTheRightHasNoRoom() {
        let nearEdge = CGRect(x: 1400, y: 300, width: 248, height: 180)
        let frame = ColorWindowPlacement.frame(bubble: nearEdge, size: size, visible: visible)
        #expect(frame.maxX == nearEdge.minX - 16)
        #expect(frame.minY == nearEdge.minY)
    }

    @Test func staysOnScreenWhenNeitherSideHasRoom() {
        let wide = CGRect(x: 10, y: 300, width: 1690, height: 180)
        let frame = ColorWindowPlacement.frame(bubble: wide, size: size, visible: visible)
        #expect(frame.minX >= visible.minX)
        #expect(frame.maxX <= visible.maxX)
    }

    @Test func risesToStayAboveTheBottomEdge() {
        let low = CGRect(x: 540, y: -40, width: 248, height: 180)
        let frame = ColorWindowPlacement.frame(bubble: low, size: size, visible: visible)
        #expect(frame.minY == visible.minY)
    }

    @Test func dropsToStayBelowTheTopEdge() {
        let high = CGRect(x: 540, y: 1000, width: 248, height: 180)
        let frame = ColorWindowPlacement.frame(bubble: high, size: size, visible: visible)
        #expect(frame.maxY == visible.maxY)
    }

    @Test func followsTheDisplayTheBubbleIsOn() {
        let second = CGRect(x: 1710, y: 0, width: 1920, height: 1080)
        let nearItsRight = CGRect(x: 1710 + 1500, y: 300, width: 300, height: 180)
        let frame = ColorWindowPlacement.frame(bubble: nearItsRight, size: size, visible: second)
        #expect(frame.maxX == nearItsRight.minX - 16)
        #expect(frame.minX >= second.minX)
    }
}

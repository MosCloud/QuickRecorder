//
//  SizeTagTests.swift
//  QuickRecorderTests
//
//  Where the area selector shows the area's size (issue #110).
//

import Foundation
import Testing

@Suite("The area's size tag")
struct SizeTagTests {
    // A 15" MacBook Air: 1710×1107 points, a 185×33.5 notch in the middle; the tag reads "1350 × 790"
    let air = CGSize(width: 1710, height: 1107)
    let notch = CGRect(x: 762.5, y: 0, width: 185, height: 33.5)
    let tag = CGSize(width: 92, height: 23)

    func center(_ area: CGRect, notch: CGRect? = nil, screen: CGSize? = nil) -> CGPoint {
        SizeTag.center(area: area, tag: tag, screen: screen ?? air, notch: notch)
    }

    @Test("Inside the area, centred 10 points below its top")
    func inside() {
        #expect(center(CGRect(x: 180, y: 200, width: 900, height: 560), notch: notch) == CGPoint(x: 630, y: 221.5))
    }

    @Test("Under the notch it moves down to 6 points below it")
    func underTheNotch() {
        #expect(center(CGRect(x: 405, y: 0, width: 900, height: 500), notch: notch) == CGPoint(x: 855, y: 51))
        #expect(center(CGRect(origin: .zero, size: air), notch: notch) == CGPoint(x: 855, y: 51))
    }

    @Test("Beside the notch it stays 10 points below the top, menu bar or not")
    func besideTheNotch() {
        #expect(center(CGRect(x: 60, y: 14, width: 560, height: 380), notch: notch) == CGPoint(x: 340, y: 35.5))
    }

    @Test("Within 6 points of the notch's side counts as under it", arguments: [
        (711.5, 51.0),  // the tag's right edge 5 points from the notch
        (709.5, 21.5),  // 7 points
    ])
    func nearTheSide(midX: CGFloat, y: CGFloat) {
        #expect(center(CGRect(x: midX - 200, y: 0, width: 400, height: 300), notch: notch) == CGPoint(x: midX, y: y))
    }

    @Test("Within 6 points below the notch counts as under it", arguments: [
        (29.0, 51.0),  // the tag's top would be at 39, half a point inside
        (30.0, 51.5),  // at 40, clear of it
    ])
    func nearTheBottom(top: CGFloat, y: CGFloat) {
        #expect(center(CGRect(x: 405, y: top, width: 900, height: 400), notch: notch) == CGPoint(x: 855, y: y))
    }

    @Test("On a screen without a notch the top is like anywhere else")
    func withoutNotch() {
        let external = CGSize(width: 1920, height: 1080)
        #expect(center(CGRect(x: 510, y: 0, width: 900, height: 500), screen: external) == CGPoint(x: 960, y: 21.5))
    }

    @Test("An area too narrow or too short to hold it has it just above")
    func aboveSmallAreas() {
        #expect(center(CGRect(x: 240, y: 220, width: 70, height: 320), notch: notch) == CGPoint(x: 275, y: 200.5))
        #expect(center(CGRect(x: 555, y: 380, width: 600, height: 36), notch: notch) == CGPoint(x: 855, y: 360.5))
    }

    @Test("Just below a small area when above it is off screen, kept on screen sideways")
    func belowAtTheTop() {
        #expect(center(CGRect(x: 0, y: 0, width: 60, height: 30), notch: notch) == CGPoint(x: 50, y: 49.5))
    }

    @Test("Just below a small area when above it would be under the notch")
    func belowUnderTheNotch() {
        #expect(center(CGRect(x: 810, y: 0, width: 90, height: 48), notch: notch) == CGPoint(x: 855, y: 67.5))
        #expect(center(CGRect(x: 810, y: 60, width: 90, height: 40), notch: notch) == CGPoint(x: 855, y: 119.5))
    }

    @Test("Above a small area at the bottom of the screen")
    func atTheBottom() {
        #expect(center(CGRect(x: 1650, y: 1077, width: 60, height: 30), notch: notch) == CGPoint(x: 1660, y: 1057.5))
    }

    @Test("With room neither above nor below a small area, at the bottom of the screen")
    func fullHeight() {
        #expect(center(CGRect(x: 100, y: 0, width: 60, height: 1107), notch: notch) == CGPoint(x: 130, y: 1091.5))
    }
}

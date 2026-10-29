//
//  AreaRectTests.swift
//  QuickRecorderTests
//
//  The area selector's rectangle: where it starts on a screen it has not seen, what a remembered one becomes on a
//  screen it no longer fits, what changing the size does to the place, and how one screen's rectangle is kept
//  without losing another's (issue #113).
//

import Foundation
import Testing

@Suite("The area selector's rectangle")
struct AreaRectTests {
    /// The owner's MacBook Air: 1710×1107 points, the visible frame 988 tall after the menu bar and the Dock
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1107)
    let visible = CGRect(x: 0, y: 85, width: 1710, height: 988)

    @Test("A new screen starts at 60% of its visible frame, in the middle of it")
    func initialIsSixtyPercentCentred() {
        let rect = AreaRect.initial(visible: visible)
        #expect(rect.size == CGSize(width: 1026, height: 592))
        #expect(rect.midX == visible.midX)
        #expect(rect.midY == visible.midY)
        #expect(visible.contains(rect))
    }

    @Test("A screen too small for 60% still gets a rectangle big enough to use")
    func initialKeepsAMinimum() {
        let small = CGRect(x: 0, y: 30, width: 800, height: 366)
        let rect = AreaRect.initial(visible: small)
        #expect(rect.width == 480)
        #expect(rect.height == 270)
        #expect(small.contains(rect))
    }

    @Test("A remembered rectangle that is too big for the screen shrinks, keeping its middle and its shape")
    func restoredShrinks() {
        let saved = CGRect(x: 0, y: 0, width: 1710, height: 1300)
        let rect = AreaRect.restored(saved, screen: screen, visible: visible)
        #expect(rect.height == screen.height)
        #expect(abs(rect.width / rect.height - 1710.0 / 1300.0) < 0.001)
        #expect(rect.midX == saved.midX)
        #expect(screen.contains(rect))
    }

    @Test("A remembered rectangle off the screen edge comes back inside it")
    func restoredComesBack() {
        let saved = CGRect(x: -300, y: -400, width: 600, height: 400)
        let rect = AreaRect.restored(saved, screen: screen, visible: visible)
        #expect(rect.size == saved.size)
        #expect(rect.minX == screen.minX)
        #expect(rect.minY == screen.minY)
    }

    @Test("A remembered rectangle with no size is no memory at all, so the screen starts fresh")
    func restoredIgnoresAnEmptyOne() {
        #expect(AreaRect.restored(CGRect(x: 10, y: 10, width: 0, height: 500), screen: screen, visible: visible)
                == AreaRect.initial(visible: visible))
        #expect(AreaRect.restored(nil, screen: screen, visible: visible) == AreaRect.initial(visible: visible))
    }

    @Test("A remembered rectangle too small to be a choice is a stray click's leftover, so the screen starts fresh")
    func restoredIgnoresATinyOne() {
        let leftover = CGRect(x: 864, y: 525, width: 0.297, height: 0.594)
        #expect(AreaRect.restored(leftover, screen: screen, visible: visible) == AreaRect.initial(visible: visible))
        let almost = CGRect(x: 100, y: 200, width: 19, height: 40)
        #expect(AreaRect.restored(almost, screen: screen, visible: visible) == AreaRect.initial(visible: visible))
    }

    @Test("Changing the size keeps the middle where it was")
    func resizedKeepsTheMiddle() {
        let rect = CGRect(x: 342, y: 282, width: 600, height: 450)
        let bigger = AreaRect.resized(rect, to: CGSize(width: 900, height: 700), screen: screen)
        #expect(bigger.size == CGSize(width: 900, height: 700))
        #expect(bigger.midX == rect.midX)
        #expect(bigger.midY == rect.midY)
    }

    @Test("A size too big for the screen is cut to the screen")
    func resizedStaysOnScreen() {
        let rect = CGRect(x: 342, y: 282, width: 600, height: 450)
        let huge = AreaRect.resized(rect, to: CGSize(width: 3000, height: 2000), screen: screen)
        #expect(huge.size == screen.size)
        #expect(screen.contains(huge))
    }

    @Test("A rectangle drawn over the menu bar comes back where it was, not 37 points lower")
    func restoredKeepsTheMenuBarStrip() {
        let overTheMenuBar = CGRect(x: 400, y: 807, width: 800, height: 300)
        #expect(AreaRect.restored(overTheMenuBar, screen: screen, visible: visible) == overTheMenuBar)
    }

    @Test("A rectangle drawn over the Dock comes back where it was, not 85 points higher")
    func restoredKeepsTheDockStrip() {
        let overTheDock = CGRect(x: 400, y: 0, width: 800, height: 200)
        #expect(AreaRect.restored(overTheDock, screen: screen, visible: visible) == overTheDock)
    }

    @Test("The whole screen comes back as the whole screen, not shrunk to the visible frame")
    func restoredKeepsTheWholeScreen() {
        #expect(AreaRect.restored(screen, screen: screen, visible: visible) == screen)
    }

    @Test("Editing the size accepts the screen's own height, which the fields offer")
    func resizedAcceptsTheScreenHeight() {
        let rect = CGRect(x: 400, y: 807, width: 800, height: 300)
        let tall = AreaRect.resized(rect, to: CGSize(width: 800, height: 1107), screen: screen)
        #expect(tall.height == 1107)
        #expect(screen.contains(tall))
    }

    @Test("A Dock on the left or hidden changes nothing about what comes back")
    func restoredIgnoresTheDockSide() {
        let leftDock = CGRect(x: 82, y: 0, width: 1628, height: 1107)
        let hidden = screen
        let saved = CGRect(x: 100, y: 900, width: 600, height: 200)
        #expect(AreaRect.restored(saved, screen: screen, visible: leftDock) == saved)
        #expect(AreaRect.restored(saved, screen: screen, visible: hidden) == saved)
    }

    @Test("Saving one screen's rectangle keeps the others")
    func savingKeepsOtherScreens() {
        let other: [String: [String: CGFloat]] = ["DELL U2720Q": ["x": 10, "y": 20, "width": 800, "height": 600]]
        let saved = AreaRect.saving(other, screen: "Built-in Retina Display",
                                    rect: CGRect(x: 342, y: 282, width: 1026, height: 593))
        #expect(saved.count == 2)
        #expect(saved["DELL U2720Q"]?["width"] == 800)
        #expect(saved["Built-in Retina Display"]?["x"] == 342)
        #expect(saved["Built-in Retina Display"]?["height"] == 593)
    }

    @Test("Saving and reading back the same screen replaces only that one")
    func savingReplacesTheSameScreen() {
        let once = AreaRect.saving([:], screen: "A", rect: CGRect(x: 1, y: 2, width: 3, height: 4))
        let twice = AreaRect.saving(once, screen: "A", rect: CGRect(x: 5, y: 6, width: 7, height: 8))
        #expect(twice.count == 1)
        #expect(twice["A"]?["x"] == 5)
    }
}

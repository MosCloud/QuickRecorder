//
//  PickerHoldTests.swift
//  QuickRecorderTests
//

import Foundation
import Testing

@Suite("What keeps the menu bar and the Dock off the screen")
struct PickerHoldTests {
    /// Whatever the app's presentation options were before a picker held anything
    private let before: UInt = 0b101

    @Test("The first window to hold hides them, remembering what was there")
    func firstHold() {
        var hold = PickerHold<String>()
        #expect(hold.hold("area", current: before) == .hide)
        #expect(hold.isHolding)
    }

    @Test("Holding the same window again changes nothing")
    func sameWindowTwice() {
        var hold = PickerHold<String>()
        _ = hold.hold("area", current: before)
        #expect(hold.hold("area", current: before) == .none)
    }

    @Test("A second window doesn't hide them again")
    func secondWindow() {
        var hold = PickerHold<String>()
        _ = hold.hold("area", current: before)
        #expect(hold.hold("cover", current: 0) == .none)
    }

    @Test("A window that never held changes nothing when released")
    func unknownRelease() {
        var hold = PickerHold<String>()
        #expect(hold.release("cover") == .none)
        #expect(!hold.isHolding)
    }

    @Test("Releasing one of two holders keeps them off the screen")
    func oneOfTwo() {
        var hold = PickerHold<String>()
        _ = hold.hold("area", current: before)
        _ = hold.hold("cover", current: before)
        #expect(hold.release("area") == .none)
        #expect(hold.isHolding)
        #expect(hold.release("cover") == .restore(before))
    }

    @Test("The last release puts back the options from the first hold, whatever the order")
    func lastReleaseRestores() {
        var hold = PickerHold<String>()
        _ = hold.hold("area", current: before)
        _ = hold.hold("cover", current: 0)
        #expect(hold.release("cover") == .none)
        #expect(hold.release("area") == .restore(before))
    }

    @Test("Holding again after everything was released saves the new options")
    func holdAgain() {
        var hold = PickerHold<String>()
        _ = hold.hold("area", current: before)
        #expect(hold.release("area") == .restore(before))
        #expect(hold.hold("cover", current: 0b10) == .hide)
        #expect(hold.release("cover") == .restore(0b10))
    }

    @Test("Releasing twice restores once")
    func releaseTwice() {
        var hold = PickerHold<String>()
        _ = hold.hold("area", current: before)
        #expect(hold.release("area") == .restore(before))
        #expect(hold.release("area") == .none)
    }
}

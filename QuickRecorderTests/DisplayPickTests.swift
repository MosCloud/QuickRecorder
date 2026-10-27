//
//  DisplayPickTests.swift
//  QuickRecorderTests
//
//  Which display a scripted recording uses (issue #72).
//

import Foundation
import Testing

@Suite("Display for a scripted recording")
struct DisplayPickTests {
    let all = ["built-in", "external"]

    @Test("The pointer's display, when the window is on it")
    func pointer() {
        #expect(DisplayPick.pick(pointer: "external", candidates: all, all: all) == "external")
    }

    @Test("The window's display, when the pointer is on another one")
    func elsewhere() {
        #expect(DisplayPick.pick(pointer: "external", candidates: ["built-in"], all: all) == "built-in")
    }

    @Test("Without the pointer's display (the screen locked or asleep), the window's: before, nothing happened at all")
    func noPointer() {
        #expect(DisplayPick.pick(pointer: nil, candidates: ["external"], all: all) == "external")
    }

    @Test("For audio, which has no window: the pointer's display, else any")
    func audio() {
        #expect(DisplayPick.pick(pointer: "external", candidates: [], all: all) == "external")
        #expect(DisplayPick.pick(pointer: nil, candidates: [], all: all) == "built-in")
    }

    @Test("No display at all: nothing, to say so")
    func none() {
        #expect(DisplayPick.pick(pointer: nil as String?, candidates: [], all: []) == nil)
    }
}

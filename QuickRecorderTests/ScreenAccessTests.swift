//
//  ScreenAccessTests.swift
//  QuickRecorderTests
//
//  What QuickRecorder does when it's refused the screen's content (issue #5).
//

import Foundation
import Testing

@Suite("Screen recording refused")
struct ScreenAccessTests {
    @Test("At launch or in the background, nothing is asked again: macOS shows its own prompt, once", arguments: [true, false])
    func unasked(allowedInSettings: Bool) {
        #expect(ScreenAccess.refused(userAsked: false, allowedInSettings: allowedInSettings) == .none)
    }

    @Test("Starting a recording without the permission explains it, with the way to System Settings")
    func explain() {
        #expect(ScreenAccess.refused(userAsked: true, allowedInSettings: false) == .explain)
    }

    @Test("Allowed in System Settings yet still refused: it takes reopening QuickRecorder, and that's what it says")
    func reopen() {
        #expect(ScreenAccess.refused(userAsked: true, allowedInSettings: true) == .reopen)
    }
}

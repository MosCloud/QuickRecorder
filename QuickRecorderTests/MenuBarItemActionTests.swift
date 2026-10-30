//
//  MenuBarItemActionTests.swift
//  QuickRecorderTests
//

import Foundation
import Testing

@Suite("What the menu bar item does on a sync")
struct MenuBarItemActionTests {
    @Test("Idle, the item follows the show-on-menu-bar setting")
    func idle() {
        #expect(MenuBarItemAction.decide(recording: false, statusItem: true, showInMenuBar: true) == .showIdle(visible: true))
        #expect(MenuBarItemAction.decide(recording: false, statusItem: true, showInMenuBar: false) == .showIdle(visible: false))
    }

    @Test("Recording with the menu bar timer on switches the item to the timer")
    func recordingWithTimer() {
        #expect(MenuBarItemAction.decide(recording: true, statusItem: true, showInMenuBar: true) == .showRecording)
        // The two settings are independent: the timer shows even with the idle item turned off
        #expect(MenuBarItemAction.decide(recording: true, statusItem: true, showInMenuBar: false) == .showRecording)
    }

    @Test("Recording with the menu bar timer off leaves the item untouched, so the timer never flashes (#192)")
    func recordingWithoutTimer() {
        // This is the case that flashed: the look used to be built and then hidden one frame later
        #expect(MenuBarItemAction.decide(recording: true, statusItem: false, showInMenuBar: true) == .stayHidden)
        #expect(MenuBarItemAction.decide(recording: true, statusItem: false, showInMenuBar: false) == .stayHidden)
    }

    @Test("Only a recording can leave the item hidden: idle always picks a visible setting")
    func onlyRecordingHides() {
        for show in [true, false] {
            #expect(MenuBarItemAction.decide(recording: false, statusItem: false, showInMenuBar: show) != .stayHidden)
        }
    }
}

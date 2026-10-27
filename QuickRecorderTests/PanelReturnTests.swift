//
//  PanelReturnTests.swift
//  QuickRecorderTests
//
//  When the main panel comes back after a recording, or the setup for one, that started from it (issue #53).
//

import Foundation
import Testing

@Suite("Return to the main panel")
struct PanelReturnTests {
    @Test("Backing out of a picker brings the panel back, once")
    func backOut() {
        var state = PanelReturn()
        state.tileChosen()
        let backedOut = state.windowClosed(othersOpen: false, recording: false)
        let again = state.windowClosed(othersOpen: false, recording: false)
        #expect(backedOut)
        #expect(!again)
    }

    @Test("Moving from one picker to another doesn't, until the last one closes")
    func switchPickers() {
        var state = PanelReturn()
        state.tileChosen()
        let switched = state.windowClosed(othersOpen: true, recording: false)
        let closed = state.windowClosed(othersOpen: false, recording: false)
        #expect(!switched)
        #expect(closed)
    }

    @Test("Pressing Start closes the picker without bringing the panel back; the recording's end does")
    func recording() {
        var state = PanelReturn()
        state.tileChosen()
        state.startPressed()
        let pickerClosed = state.windowClosed(othersOpen: false, recording: false)
        state.recordingStarted()
        let countdownClosed = state.windowClosed(othersOpen: false, recording: true)
        let ended = state.recordingEnded(trimmerOpens: false)
        #expect(!pickerClosed)
        #expect(!countdownClosed)
        #expect(ended)
    }

    @Test("Cancelling the countdown brings the panel back")
    func cancelCountdown() {
        var state = PanelReturn()
        state.tileChosen()
        state.startPressed()
        let cancelled = state.countdownCancelled()
        #expect(cancelled)
    }

    @Test("With the trimmer opening after the recording, the panel waits for it to close")
    func trimmer() {
        var state = PanelReturn()
        state.tileChosen()
        state.startPressed()
        state.recordingStarted()
        let ended = state.recordingEnded(trimmerOpens: true)
        let trimmerClosed = state.windowClosed(othersOpen: false, recording: false)
        #expect(!ended)
        #expect(trimmerClosed)
    }

    @Test("A recording started by a hotkey or from the menu bar panel leaves the panel alone")
    func elsewhere() {
        var state = PanelReturn()
        state.startPressed()
        state.recordingStarted()
        let ended = state.recordingEnded(trimmerOpens: false)
        #expect(!ended)
    }

    @Test("So does one started by a hotkey while a picker from the panel is open")
    func hotkeyWhilePicking() {
        var state = PanelReturn()
        state.tileChosen()
        state.recordingStarted()
        let pickerClosed = state.windowClosed(othersOpen: false, recording: true)
        let ended = state.recordingEnded(trimmerOpens: false)
        let laterClose = state.windowClosed(othersOpen: false, recording: false)
        #expect(!pickerClosed)
        #expect(!ended)
        #expect(!laterClose)
    }

    @Test("Closing Settings opened from the panel brings it back, once (#66)")
    func settings() {
        var state = PanelReturn()
        state.settingsOpened()
        let closed = state.windowClosed(othersOpen: false, recording: false)
        let again = state.windowClosed(othersOpen: false, recording: false)
        #expect(closed)
        #expect(!again)
    }

    @Test("Settings opened elsewhere don't bring the panel back")
    func settingsElsewhere() {
        var state = PanelReturn()
        let closed = state.windowClosed(othersOpen: false, recording: false)
        #expect(!closed)
    }

    @Test("A hotkey recording started while Settings is open ends the panel's flow")
    func hotkeyFromSettings() {
        var state = PanelReturn()
        state.settingsOpened()
        state.recordingStarted()
        let settingsClosed = state.windowClosed(othersOpen: false, recording: true)
        let ended = state.recordingEnded(trimmerOpens: false)
        #expect(!settingsClosed)
        #expect(!ended)
    }
}

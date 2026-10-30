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

    @Test("Opening the menu bar panel ends the panel's flow: the windows it closes don't bring the panel back")
    func menuBarPanel() {
        var fromSettings = PanelReturn()
        fromSettings.settingsOpened()
        fromSettings.menuBarPanelOpened(mainPanelOpen: true)
        let settingsClosed = fromSettings.windowClosed(othersOpen: false, recording: false)
        var fromPicker = PanelReturn()
        fromPicker.tileChosen()
        fromPicker.menuBarPanelOpened(mainPanelOpen: true)
        let pickerClosed = fromPicker.windowClosed(othersOpen: false, recording: false)
        #expect(!settingsClosed)
        #expect(!pickerClosed)
    }
}

@Suite("The menu bar panel hands the main panel back")
struct MenuBarPanelReturnTests {
    @Test("A panel that merely stood open comes back when the menu bar panel closes (#200)")
    func standingPanelComesBack() {
        var state = PanelReturn()
        state.menuBarPanelOpened(mainPanelOpen: true)
        let returned = state.menuBarPanelClosed()
        #expect(returned)
    }

    @Test("With no panel open, closing the menu bar panel leaves the desktop alone")
    func nothingToBringBack() {
        var state = PanelReturn()
        state.menuBarPanelOpened(mainPanelOpen: false)
        let returned = state.menuBarPanelClosed()
        #expect(!returned)
    }

    @Test("A panel whose picker was open also comes back: its flow is abandoned either way (#200)")
    func pickerFlowAbandoned() {
        var state = PanelReturn()
        state.tileChosen()
        state.menuBarPanelOpened(mainPanelOpen: true)
        // The abandoned flow must not also report a return of its own, or the panel would come back twice
        let flowReturned = state.windowClosed(othersOpen: false, recording: false)
        let panelReturned = state.menuBarPanelClosed()
        #expect(!flowReturned)
        #expect(panelReturned)
    }

    @Test("It comes back once, not every time the panel closes")
    func comesBackOnce() {
        var state = PanelReturn()
        state.menuBarPanelOpened(mainPanelOpen: true)
        let first = state.menuBarPanelClosed()
        let second = state.menuBarPanelClosed()
        #expect(first)
        #expect(!second)
    }

    @Test("A recording started from the menu bar panel keeps the old panel away")
    func recordingTakesOver() {
        var state = PanelReturn()
        state.menuBarPanelOpened(mainPanelOpen: true)
        state.menuBarPanelTileChosen()
        let returned = state.menuBarPanelClosed()
        #expect(!returned)
    }

    @Test("A picker opened from a panel tile brings the main panel back when it closes (#203)")
    func pickerFromPanelTile() {
        var state = PanelReturn()
        state.menuBarPanelOpened(mainPanelOpen: false)
        state.menuBarPanelTileChosen()
        // The panel itself closed when the picker opened: nothing to hand back then
        let panelClosed = state.menuBarPanelClosed()
        // Backing out of the picker brings the panel, the same as the same tile in the main panel
        let pickerClosed = state.windowClosed(othersOpen: false, recording: false)
        #expect(!panelClosed)
        #expect(pickerClosed)
    }

    @Test("Starting the recording from that picker still waits for the recording to end (#203)")
    func pickerFromPanelTileThenRecording() {
        var state = PanelReturn()
        state.menuBarPanelOpened(mainPanelOpen: false)
        state.menuBarPanelTileChosen()
        state.startPressed()
        let pickerClosed = state.windowClosed(othersOpen: false, recording: false)
        state.recordingStarted()
        let ended = state.recordingEnded(trimmerOpens: false)
        #expect(!pickerClosed)
        #expect(ended)
    }

    @Test("The next opening starts from what is on screen then, not from the last one")
    func secondOpening() {
        var state = PanelReturn()
        state.menuBarPanelOpened(mainPanelOpen: true)
        let firstClose = state.menuBarPanelClosed()
        state.menuBarPanelOpened(mainPanelOpen: false)
        let secondClose = state.menuBarPanelClosed()
        #expect(firstClose)
        #expect(!secondClose)
    }
}

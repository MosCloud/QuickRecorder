//
//  PanelReturn.swift
//  QuickRecorder
//

/// When the main panel comes back: a recording, or the setup for one, that started from it has ended (#53),
/// or Settings opened from it closed (#66). Recordings and Settings started elsewhere (a hotkey, the menu bar panel) leave it alone.
///
/// One question decides all of it: **was the main panel on screen when the user started this flow?** If it was, the
/// panel comes back when the flow ends, whichever window the flow ran in; if it was not, nothing is brought back.
/// The menu bar panel fits the same rule (#200, #203): it closes every window when it opens, so the answer is recorded
/// at that moment, and whichever window ends the flow spends it.
struct PanelReturn {
    private enum Phase { case idle, choosing, starting }
    private var phase = Phase.idle
    /// The main panel was on screen when this flow started, so ending the flow has to bring it back
    private var mainPanelExpected = false

    /// A main panel tile opened a picker or started a countdown. The panel is on screen by definition, so it is
    /// expected back when the flow ends.
    mutating func tileChosen() {
        phase = .choosing
        mainPanelExpected = true
    }

    /// The main panel's Preferences button opened Settings: closing it is backing out, as from a picker.
    mutating func settingsOpened() {
        phase = .choosing
        mainPanelExpected = true
    }

    /// The menu bar panel opened, closing every window. Whatever the main panel was setting up is abandoned; what
    /// stays is the answer to whether it should come back at all.
    /// - Parameter mainPanelOpen: the main panel was on screen at that moment.
    mutating func menuBarPanelOpened(mainPanelOpen: Bool) {
        phase = .idle
        mainPanelExpected = mainPanelOpen
    }

    /// The menu bar panel closed: true when the main panel it displaced has to come back. A panel that was not open
    /// is never brought up by someone else's window closing (#203).
    mutating func menuBarPanelClosed() -> Bool {
        guard mainPanelExpected, phase == .idle else { return false }
        mainPanelExpected = false
        return true
    }

    /// A tile of the menu bar panel opened a picker or started a countdown: the picker is the flow now. Whether the
    /// main panel comes back when the picker closes was settled when the panel opened, so it is not touched here (#203).
    mutating func menuBarPanelTileChosen() {
        phase = .choosing
    }

    /// Start was pressed: a countdown, then a recording, is on its way.
    mutating func startPressed() {
        if phase == .choosing { phase = .starting }
    }

    /// A recording started: if it didn't come through the panel's Start (a hotkey, say), the panel's flow is over.
    mutating func recordingStarted() {
        if phase == .choosing { phase = .idle }
    }

    /// A window of the flow closed, `othersOpen` telling whether any is still open: true when that was backing out.
    mutating func windowClosed(othersOpen: Bool, recording: Bool) -> Bool {
        guard phase == .choosing, !othersOpen, !recording else { return false }
        phase = .idle
        return spend()
    }

    mutating func countdownCancelled() -> Bool {
        guard phase == .starting else { return false }
        phase = .idle
        return spend()
    }

    /// With the trimmer opening, the panel comes back once the trimmer closes.
    mutating func recordingEnded(trimmerOpens: Bool) -> Bool {
        guard phase == .starting else { return false }
        if trimmerOpens {
            phase = .choosing
            return false
        }
        phase = .idle
        return spend()
    }

    /// Takes the pending answer, so only the window that ends the flow brings the panel back.
    private mutating func spend() -> Bool {
        defer { mainPanelExpected = false }
        return mainPanelExpected
    }
}

//
//  PanelReturn.swift
//  QuickRecorder
//

/// When the main panel comes back: a recording, or the setup for one, that started from it has ended (#53),
/// or Settings opened from it closed (#66). Recordings and Settings started elsewhere (a hotkey, the menu bar panel) leave it alone.
///
/// The menu bar panel has to hand the panel back too (#200): opening it closes every window, the main panel included.
/// A panel that was merely standing open comes back when that panel closes; one whose flow was abandoned does not.
struct PanelReturn {
    private enum Phase { case idle, choosing, starting }
    private var phase = Phase.idle
    /// The main panel was on screen when the menu bar panel opened, so closing that panel has to bring it back (#200)
    private var mainPanelWasOpen = false

    /// A main panel tile opened a picker or started a countdown.
    mutating func tileChosen() {
        phase = .choosing
    }

    /// The panel's Preferences button opened Settings: closing it is backing out, as from a picker.
    mutating func settingsOpened() {
        phase = .choosing
    }

    /// The menu bar panel opened, closing every window: whatever the main panel was setting up is abandoned.
    /// - Parameter mainPanelOpen: whether the main panel was on screen at that moment, which decides if it comes back.
    mutating func menuBarPanelOpened(mainPanelOpen: Bool) {
        phase = .idle
        mainPanelWasOpen = mainPanelOpen
    }

    /// The menu bar panel closed: true when the main panel it displaced has to come back.
    mutating func menuBarPanelClosed() -> Bool {
        defer { mainPanelWasOpen = false }
        return mainPanelWasOpen
    }

    /// Something else took the panel's place while the menu bar panel was up (a recording started from its tiles,
    /// Settings from its gear): closing it must not bring the old main panel back on top of that.
    mutating func menuBarPanelTookOver() {
        mainPanelWasOpen = false
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
        return true
    }

    mutating func countdownCancelled() -> Bool {
        guard phase == .starting else { return false }
        phase = .idle
        return true
    }

    /// With the trimmer opening, the panel comes back once the trimmer closes.
    mutating func recordingEnded(trimmerOpens: Bool) -> Bool {
        guard phase == .starting else { return false }
        if trimmerOpens {
            phase = .choosing
            return false
        }
        phase = .idle
        return true
    }
}

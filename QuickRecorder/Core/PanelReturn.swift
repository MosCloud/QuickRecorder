//
//  PanelReturn.swift
//  QuickRecorder
//

/// When the main panel comes back: a recording, or the setup for one, that started from it has ended (#53),
/// or Settings opened from it closed (#66). Recordings and Settings started elsewhere (a hotkey, the menu bar panel) leave it alone.
struct PanelReturn {
    private enum Phase { case idle, choosing, starting }
    private var phase = Phase.idle

    /// A main panel tile opened a picker or started a countdown.
    mutating func tileChosen() {
        phase = .choosing
    }

    /// The panel's Preferences button opened Settings: closing it is backing out, as from a picker.
    mutating func settingsOpened() {
        phase = .choosing
    }

    /// The menu bar panel opened, closing every window: whatever the main panel was setting up is abandoned.
    mutating func menuBarPanelOpened() {
        phase = .idle
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

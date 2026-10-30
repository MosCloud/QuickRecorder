//
//  MainPanelReturn.swift
//  QuickRecorder
//
//  Brings the main panel back when a recording, or the setup for one, that started from it ends (#53),
//  and when Settings opened from it closes (#66).
//

import AppKit

@MainActor
final class MainPanelReturn {
    static let shared = MainPanelReturn()
    private var state = PanelReturn()
    private var wasRecording = false
    private var recordedVideo = false

    private init() {
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                guard Self.isFlowWindow(window) else { return }
                // A moment later: the closing window is still on screen now, and a picker closes before the next one opens
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    MainActor.assumeIsolated { MainPanelReturn.shared.windowClosed() }
                }
            }
        }
    }

    /// A main panel tile opened a picker or started a countdown.
    func tileChosen() { state.tileChosen() }

    func settingsOpened() { state.settingsOpened() }

    /// - Parameter mainPanelOpen: the main panel was on screen when the menu bar panel opened.
    func menuBarPanelOpened(mainPanelOpen: Bool) { state.menuBarPanelOpened(mainPanelOpen: mainPanelOpen) }

    /// The menu bar panel closed: bring the main panel back if it was open before, unless something took its place.
    func menuBarPanelClosed() {
        if state.menuBarPanelClosed() { show() }
    }

    /// The menu bar panel is about to start a recording or open Settings: the main panel must not come back after it.
    func menuBarPanelTookOver() { state.menuBarPanelTookOver() }

    /// Whether the main panel is on screen right now, read from the windows rather than from any remembered flag.
    var mainPanelIsOpen: Bool { AppDelegate.shared.mainPanelWindow != nil }

    /// Start was pressed in a picker, or the panel started a recording itself.
    func startPressed() { state.startPressed() }

    func countdownCancelled() {
        if state.countdownCancelled() { show() }
    }

    /// Follows the recording starting and stopping; called whenever the recording controls sync.
    func recordingChanged() {
        let recording = SCContext.streamType != nil
        defer { wasRecording = recording }
        if recording && !wasRecording {
            recordedVideo = RecordingKind.current == .video
            state.recordingStarted()
        } else if !recording && wasRecording {
            if state.recordingEnded(trimmerOpens: recordedVideo && ud.bool(forKey: "trimAfterRecord")) { show() }
        }
    }

    private func windowClosed() {
        let othersOpen = NSApp.windows.contains { $0.isVisible && Self.isFlowWindow($0) }
        if state.windowClosed(othersOpen: othersOpen, recording: SCContext.streamType != nil) { show() }
    }

    /// Pickers, the countdown, the trimmer, Settings: titled windows other than the main panel itself and the preview
    private static func isFlowWindow(_ window: NSWindow) -> Bool {
        !window.title.isEmpty && window.title != "Item-0" && window.title != "QuickRecorder".local && window !== previewWindow
    }

    private func show() {
        AppDelegate.shared.showMainPanel()
    }
}

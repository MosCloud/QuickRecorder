//
//  OwnWindows.swift
//  QuickRecorder
//

import Foundation

/// What a capture filter does with QuickRecorder's own windows (#13). Generic over the app and window types,
/// ScreenCaptureKit's in the app.
struct OwnWindows<App, Window> {
    /// Left out on top of the user's own list (screen and area recordings)
    var excludedApps: [App] = []
    /// Recorded on top of the chosen apps (app recordings)
    var includedApps: [App] = []
    /// The filter's excepting windows: shown if their app is left out, or isn't among the recorded ones; hidden otherwise
    var exceptions: [Window] = []
}

extension OwnWindows {
    /// `overlays` are the windows meant to be recorded (camera, iPhone, highlighted pointer), `capsule` the recording controls,
    /// `opened` QuickRecorder's other windows open as the recording starts.
    static func screen(hideSelf: Bool, app: App?, overlays: [Window], capsule: [Window], opened: [Window]) -> Self {
        guard hideSelf else { return Self(exceptions: capsule) }
        // A filter knows only the windows open when it's made: leaving the app out as a whole leaves out the popovers
        // and menus it opens during the recording too
        guard let app else { return Self(exceptions: opened + capsule) }
        return Self(excludedApps: [app], exceptions: overlays)
    }

    static func apps(hideSelf: Bool, app: App?, overlays: [Window], capsule: [Window]) -> Self {
        // Not among the recorded apps, QuickRecorder's windows show only as exceptions
        guard !hideSelf, let app else { return Self(exceptions: overlays) }
        return Self(includedApps: [app], exceptions: capsule)
    }
}

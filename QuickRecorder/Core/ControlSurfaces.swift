//
//  ControlSurfaces.swift
//  QuickRecorder
//

import Foundation

/// Which recording controls are on screen: the menu bar timer and the notch capsule.
struct ControlSurfaces: Equatable {
    var statusItem: Bool
    var capsule: Bool

    /// - Parameters:
    ///   - menuBar: the "menu bar timer and menu" setting.
    ///   - capsule: the "floating capsule" setting.
    ///   - statusItemHidden: the timer can't be seen, because the notch pushed it out or a full-screen app hides the menu bar.
    static func whileRecording(menuBar: Bool, capsule: Bool, statusItemHidden: Bool) -> ControlSurfaces {
        // The settings page keeps one of them on; if both are off anyway, fall back to the defaults
        if !menuBar && !capsule { return ControlSurfaces(statusItem: true, capsule: true) }
        return ControlSurfaces(statusItem: menuBar, capsule: capsule || statusItemHidden)
    }
}

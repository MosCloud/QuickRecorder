//
//  Backdrop.swift
//  QuickRecorder
//

import Foundation

/// What a recording puts behind what it records (#83)
enum Backdrop {
    /// Whether `type` recordings use the chosen background. Screen and area recordings show the screen as it is,
    /// so a colour picked for an app can't leak into a full-screen recording started from a hotkey or a script.
    static func applies(to type: StreamType) -> Bool { [.window, .windows, .application].contains(type) }

    /// Whether a window draws the desktop picture: WindowManager's "Wallpaper" window on macOS 27, the Dock's windows
    /// other than the Dock itself and Launchpad on older systems
    static func isWallpaper(bundleID: String?, title: String?) -> Bool {
        guard let title else { return false }
        if bundleID == "com.apple.WindowManager" { return title == "Wallpaper" }
        return bundleID == "com.apple.dock" && title != "LPSpringboard" && title != "Dock"
    }
}

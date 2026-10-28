//
//  Backdrop.swift
//  QuickRecorder
//

import Foundation

/// What a recording puts behind what it records (#83)
enum Backdrop {
    /// Whether `type` recordings use the chosen background (#117: application recordings only — a window recording
    /// is the window itself, with no area for a backdrop; screen and area recordings show the screen as it is).
    static func applies(to type: StreamType) -> Bool { type == .application }

    /// Whether a window draws the desktop picture: WindowManager's "Wallpaper" window on macOS 27, the Dock's windows
    /// other than the Dock itself and Launchpad on older systems
    static func isWallpaper(bundleID: String?, title: String?) -> Bool {
        guard let title else { return false }
        if bundleID == "com.apple.WindowManager" { return title == "Wallpaper" }
        return bundleID == "com.apple.dock" && title != "LPSpringboard" && title != "Dock"
    }
}

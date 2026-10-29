//
//  PickerShield.swift
//  QuickRecorder
//

import AppKit

/// The window levels the pickers use while they own the whole screen (#163).
///
/// The Window Server gives the menu bar strip priority over ordinary windows: with a cover at `statusBar` the menu bar
/// and its items still took clicks, and its windows sit above everything an app normally opens. A picker that has to own
/// every click, the way the system's own area selection does, has to be at the shielding level — and the capsule it
/// shows above itself has to be one step higher still, or it would sit behind the cover.
enum PickerShield {
    /// The full-screen cover: above the menu bar, so a click anywhere belongs to the picker
    static let cover = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
    /// The capsule and its bubbles, over the cover
    static let above = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
}

//
//  PickerHold.swift
//  QuickRecorder
//

import Foundation

/// Which windows are keeping the menu bar and the Dock off the screen (#171).
///
/// A picker holds every window it puts up, and the window lets go when it closes: every way out of the picker puts the
/// menu bar back, whether or not the code that closed the window knew about it. Counters made that a thing to remember
/// on each exit, and the one exit that forgot left the menu bar and the Dock off until the app quit.
///
/// Foundation only: `PickerPresentation` turns a change into `NSApplication.presentationOptions`, which is why the saved
/// value is a plain `UInt`.
struct PickerHold<ID: Hashable> {
    /// What the caller has to do to the presentation options
    enum Change: Equatable {
        /// Nothing to change: another window still holds, or this one never did
        case none
        /// The first window is holding: hide the menu bar and the Dock
        case hide
        /// The last window is gone: put back what was there before the first one held
        case restore(UInt)
    }

    /// What the options were before the first window held, and what a restore has to put back
    private var saved: UInt?
    private var held: Set<ID> = []

    var isHolding: Bool { !held.isEmpty }

    /// - Parameter current: the presentation options as they are now; kept if this is the first holder
    mutating func hold(_ id: ID, current: UInt) -> Change {
        guard held.insert(id).inserted else { return .none }
        guard saved == nil else { return .none }
        saved = current
        return .hide
    }

    /// The window closed: its hold ends, and the last one puts the options back
    mutating func release(_ id: ID) -> Change {
        guard held.remove(id) != nil, held.isEmpty, let saved else { return .none }
        self.saved = nil
        return .restore(saved)
    }
}

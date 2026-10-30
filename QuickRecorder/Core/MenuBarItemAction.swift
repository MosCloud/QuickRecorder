//
//  MenuBarItemAction.swift
//  QuickRecorder
//

import Foundation

/// What the menu bar item does when the recording controls sync (#192).
///
/// The item has three states, and only two of them touch its look. A recording with the menu bar timer turned off
/// leaves the item hidden: the sync must then leave it alone entirely, because building the timer's menu and swapping
/// the button's font and image layout draws it for a frame before it can be hidden again.
enum MenuBarItemAction: Equatable {
    /// Not recording: the idle item, shown or not as the "show on menu bar" setting says.
    case showIdle(visible: Bool)
    /// Recording, with the timer on the menu bar: switch the item to the running timer.
    case showRecording
    /// Recording, with the timer turned off: the item stays hidden and nothing about it is touched.
    case stayHidden

    /// - Parameters:
    ///   - recording: a recording is running.
    ///   - statusItem: `ControlSurfaces.statusItem`, which is what the "menu bar timer and menu" setting asks for.
    ///   - showInMenuBar: the "show QuickRecorder on menu bar" setting, which decides the idle item.
    static func decide(recording: Bool, statusItem: Bool, showInMenuBar: Bool) -> MenuBarItemAction {
        guard recording else { return .showIdle(visible: showInMenuBar) }
        return statusItem ? .showRecording : .stayHidden
    }
}

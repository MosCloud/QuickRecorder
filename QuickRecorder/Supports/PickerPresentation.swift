//
//  PickerPresentation.swift
//  QuickRecorder
//

import AppKit

/// Takes the menu bar and the Dock off the screen while a picker owns it (#163).
///
/// A real click on the menu bar is handled by the system before any window sees it: even a cover at the shielding level
/// (and the app's own menu bar) took the click, which is how the menu could open over the area selector. The only
/// reliable way is for the menu bar not to be there, and AppKit only allows hiding it together with the Dock.
///
/// The frost is a picture of the screen taken as the picker opens, so it still shows both: the look barely changes.
enum PickerPresentation {
    private static var saved: NSApplication.PresentationOptions?
    private static var holders = 0

    /// Call once per picker that is up; the last one to go puts everything back
    static func begin() {
        holders += 1
        guard saved == nil else { return }
        saved = NSApp.presentationOptions
        apply(retries: 20)
    }

    /// The options only take while the app is frontmost, and becoming frontmost is asynchronous: try again until it is
    private static func apply(retries: Int) {
        guard holders > 0, saved != nil else { return }
        guard NSApp.isActive || retries == 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { apply(retries: retries - 1) }
            return
        }
        NSApp.presentationOptions.insert([.hideMenuBar, .hideDock])
    }

    static func end() {
        holders = max(0, holders - 1)
        guard holders == 0, let saved else { return }
        NSApp.presentationOptions = saved
        Self.saved = nil
    }
}

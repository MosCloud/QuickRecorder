//
//  PickerPresentation.swift
//  QuickRecorder
//

import AppKit

/// Takes the menu bar and the Dock off the screen while a picker owns it (#163), for as long as its windows do (#171).
///
/// A real click on the menu bar is handled by the system before any window sees it: even a cover at the shielding level
/// (and the app's own menu bar) took the click, which is how the menu could open over the area selector. The only
/// reliable way is for the menu bar not to be there, and AppKit only allows hiding it together with the Dock.
///
/// The frost is a picture of the screen taken as the picker opens, so it still shows both: the look barely changes.
///
/// Which windows hold it lives in `PickerHold`, and a window stops holding when it closes: every way out of a picker
/// puts the menu bar back, whether or not the code that closed the window remembered to (#171).
enum PickerPresentation {
    private typealias Hold = PickerHold<ObjectIdentifier>

    private static var place = Hold()
    /// The `willClose` observer per held window, so a window lets go by itself and nothing is left observing
    private static var watching: [ObjectIdentifier: NSObjectProtocol] = [:]

    /// Call once per window the picker puts up: the last one to close puts everything back
    static func hold(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        if watching[id] == nil {
            watching[id] = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                                  object: window, queue: .main) { _ in
                MainActor.assumeIsolated { release(window) }
            }
        }
        let change = place.hold(id, current: NSApp.presentationOptions.rawValue)
        apply(change)
    }

    private static func release(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        if let watcher = watching.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(watcher)
        }
        apply(place.release(id))
    }

    private static func apply(_ change: Hold.Change) {
        switch change {
        case .none:
            break
        case .hide:
            hideWhenFrontmost(retries: 20)
        case .restore(let options):
            NSApp.presentationOptions = NSApplication.PresentationOptions(rawValue: options)
        }
    }

    /// The options only take while the app is frontmost, and becoming frontmost is asynchronous: try again until it is
    private static func hideWhenFrontmost(retries: Int) {
        // The last window may have closed while a retry was waiting
        guard place.isHolding else { return }
        guard NSApp.isActive || retries == 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { hideWhenFrontmost(retries: retries - 1) }
            return
        }
        NSApp.presentationOptions.insert([.hideMenuBar, .hideDock])
    }
}

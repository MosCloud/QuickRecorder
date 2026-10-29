//
//  PickerPresentation.swift
//  QuickRecorder
//

import AppKit

/// Takes the menu bar and the Dock off the screen while a picker has frozen it (#163, #170), for as long as its windows
/// do (#171).
///
/// A real click on the menu bar is handled by the system before any window sees it: a cover at any window level, the
/// app's own menu bar included, took the click, which is how the menu could open over the area selector. The only
/// reliable way is for the menu bar not to be there, and AppKit only allows hiding it together with the Dock.
///
/// The frost is a picture of the screen taken before any of this, so it still shows both: the look barely changes.
///
/// Whichever windows hold it lives in `PickerHold`, and a window stops holding when it closes: every way out of a picker
/// puts the menu bar back, whether or not the code that closed the window remembered to (#171).
enum PickerPresentation {
    private typealias Hold = PickerHold<ObjectIdentifier>

    private static var place = Hold()
    /// The `willClose` observer per held window, so a window lets go by itself and nothing is left observing
    private static var watching: [ObjectIdentifier: NSObjectProtocol] = [:]
    /// The options only take while the app is frontmost: put them on again whenever it comes back
    private static var becameActive: NSObjectProtocol?

    /// Call once per window that freezes the screen: the last one to close puts everything back
    static func hold(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        if watching[id] == nil {
            watching[id] = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                                  object: window, queue: .main) { _ in
                MainActor.assumeIsolated { release(window) }
            }
        }
        if becameActive == nil {
            becameActive = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                                  object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { hideIfFrozen() }
            }
        }
        apply(place.hold(id, current: NSApp.presentationOptions.rawValue))
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
            // The app may still be coming to the front: the observer hides them once it is (#170)
            hideIfFrozen()
        case .restore(let options):
            NSApp.presentationOptions = NSApplication.PresentationOptions(rawValue: options)
        }
    }

    /// Nothing to do while the app is in the background: it has no menu bar to take off, and a script's picker leaves
    /// the app where it was (#88)
    private static func hideIfFrozen() {
        guard place.isHolding, NSApp.isActive else { return }
        NSApp.presentationOptions.insert([.hideMenuBar, .hideDock])
    }
}

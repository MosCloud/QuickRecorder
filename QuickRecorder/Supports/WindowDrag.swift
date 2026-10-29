//
//  WindowDrag.swift
//  QuickRecorder
//

import SwiftUI
import AppKit

/// Drags a window from anywhere in its content, without taking clicks away from the controls on it (#164).
///
/// A window's own `isMovableByWindowBackground` never sees the mouse-down over SwiftUI content, a `WindowDragGesture`
/// on the background only covers the background, and one on the content fires the tile's click as well. So the drag is
/// added underneath the clicks: the events still go where they always did, and once the pointer has moved far enough
/// the window is handed to AppKit's own drag loop, which cancels whatever control the press started on.
struct WindowDragEverywhere: ViewModifier {
    /// How far the pointer has to move before a press is a drag: anything less is a click, a shaky hand included
    static let threshold: CGFloat = 3

    @State private var monitor: Any?
    @State private var pressedAt: NSPoint?
    @State private var dragging = false

    func body(content: Content) -> some View {
        content.background(WindowWatcher { watch($0) })
    }

    private func watch(_ window: NSWindow?) {
        stopWatching()
        guard let window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { event in
            guard event.window === window else { return event }
            switch event.type {
            case .leftMouseDown:
                pressedAt = event.locationInWindow
                dragging = false
            case .leftMouseDragged:
                guard let start = pressedAt, !dragging else { return event }
                let away = hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y)
                guard away >= Self.threshold else { return event }
                dragging = true
                // On NSWindow since 10.11, but this SDK doesn't surface it to Swift, hence the selector
                _ = window.tryToPerform(NSSelectorFromString("performWindowDragWithEvent:"), with: event)
            case .leftMouseUp:
                let wasDragging = dragging
                pressedAt = nil
                dragging = false
                // The press was a drag: whatever control it started on must not also fire (#164)
                if wasDragging { return nil }
            default:
                break
            }
            return event
        }
    }

    private func stopWatching() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        pressedAt = nil
        dragging = false
    }
}

extension View {
    /// The window can be dragged by pressing anywhere on this view (#164)
    func dragWindowFromAnywhere() -> some View { modifier(WindowDragEverywhere()) }
}

/// Hands over the window the view ends up in, once it is in one: a background view added by a modifier is attached a
/// moment after the content, so asking for `view.window` inside the first run loop turn can come back nil
private struct WindowWatcher: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WatchedView {
        let view = WatchedView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: WatchedView, context: Context) {}

    final class WatchedView: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}

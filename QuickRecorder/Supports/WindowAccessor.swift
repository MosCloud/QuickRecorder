//
//  WindowAccessor.swift
//  QuickRecorder
//

import AppKit
import SwiftUI

/// Hands over the window a view ends up in, and says when that window closes (#155, #172).
///
/// The window comes from `viewDidMoveToWindow`, which AppKit calls once the view is attached: asking for `view.window`
/// a run loop turn later can come back nil. Closing is watched with `willCloseNotification` rather than a window
/// delegate, so two of these in one window both hear about it. The callbacks themselves run a turn later, since the view
/// is attached while SwiftUI is updating and they often write `@State`.
struct WindowAccessor: NSViewRepresentable {
    var onWindowOpen: ((NSWindow?) -> Void)?
    var onWindowClose: (() -> Void)?

    func makeNSView(context: Context) -> WatchedView {
        let view = WatchedView()
        view.onWindowOpen = onWindowOpen
        view.onWindowClose = onWindowClose
        return view
    }

    func updateNSView(_ nsView: WatchedView, context: Context) {
        nsView.onWindowOpen = onWindowOpen
        nsView.onWindowClose = onWindowClose
    }

    final class WatchedView: NSView {
        var onWindowOpen: ((NSWindow?) -> Void)?
        var onWindowClose: (() -> Void)?
        private var observer: NSObjectProtocol?
        private weak var observed: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let window = self.window
            if window !== observed {
                detach()
                observed = window
                if let window {
                    observer = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                                      object: window, queue: .main) { [weak self] _ in
                        self?.onWindowClose?()
                    }
                }
            }
            // Handed over once the update that attached the view is finished, and only if it is still that window
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window === window else { return }
                self.onWindowOpen?(window)
            }
        }

        private func detach() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            observed = nil
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }
}

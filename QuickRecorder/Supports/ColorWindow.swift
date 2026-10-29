//
//  ColorWindow.swift
//  QuickRecorder
//
//  The custom background colour window (#117). It opens from the Options bubble's Custom swatch, sits beside the
//  bubble, and stays while it is used — clicking in it or in the system colour panel keeps the bubble open.
//
//  It takes key while it is used, because Liquid Glass draws its active look only in a key window, but it never
//  becomes main and it hands key back to the selector's window when it closes. The panel is drawn with whichever of
//  the three materials `capsuleMaterial` chose, the same ones the capsule and the main panel use.
//

import AppKit
import SwiftUI

/// What the window shows: the custom background colour, kept in `userColor` so recordings pick it up as they always have
@MainActor
final class CustomColorModel: ObservableObject {
    @Published var color: Color { didSet { ud.setColor(color, forKey: "userColor") } }
    /// The swatch under the pointer, which the preview shows instead of the chosen colour
    @Published var hovered: Swatch?

    init() {
        color = ud.color(forKey: "userColor") ?? .black
    }

    var shown: Color { hovered?.color ?? color }

    func choose(_ swatch: Swatch) { color = swatch.color }
}

@MainActor
final class ColorWindow {
    static let shared = ColorWindow()

    let model = CustomColorModel()

    private var panel: NSPanel?
    private var parent: NSWindow?
    /// The bubble's view, so its place is measured when the window opens rather than remembered from a layout
    private weak var bubbleView: NSView?
    /// The last place the bubble was measured at, for when its view is gone by the time the window opens
    private var lastBubble = CGRect.zero
    private var closeObserver: NSObjectProtocol?

    var isOpen: Bool { panel?.isVisible == true }

    /// The bubble reports its view; where it is gets measured when the window opens, not during its scale-in (#105)
    func note(view: NSView) {
        bubbleView = view
        if let rect = bubbleRect { lastBubble = rect }
        if let panel { panel.setFrame(place(for: panel), display: true) }
    }

    func show() {
        guard let view = bubbleView, let window = view.window, bubble != nil else { return }
        parent = window
        if let panel {
            panel.setFrame(place(for: panel), display: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let host = NSHostingView(rootView: BackgroundColorWindow(model: model))
        let panel = ColorWindowPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                                     styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The shadow is drawn in SwiftUI: a borderless window's own shadow rims the transparent corners
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrame(place(for: panel), display: true)

        window.addChildWindow(panel, ordered: .above)
        // Key while it is used: Liquid Glass draws its active look only there
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        if let content = panel.contentView { CapsuleBubbles.shared.addHitArea(content) }

        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                              queue: .main) { _ in
            MainActor.assumeIsolated { ColorWindow.shared.close() }
        }
    }

    func close() {
        guard let panel else { return }
        // The system panel belongs to this window: it goes with it rather than outliving it
        if NSColorPanel.shared.isVisible { NSColorPanel.shared.orderOut(nil) }
        if let content = panel.contentView { CapsuleBubbles.shared.removeHitArea(content) }
        parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        parent?.makeKey()
        self.panel = nil
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
    }

    /// Where the bubble is now, in screen coordinates with the origin at the bottom left
    private var bubbleRect: CGRect? {
        guard let view = bubbleView, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    /// The bubble as it is, or where it last was: the corner of the screen is never a place to put the window
    private var bubble: CGRect? {
        bubbleRect ?? (lastBubble == .zero ? nil : lastBubble)
    }

    /// Beside the bubble on the right, flipped left when the screen has no room, bottom edges level
    private func place(for panel: NSPanel) -> CGRect {
        guard let bubble else { return panel.frame }
        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: bubble.midX, y: bubble.midY)) }
            ?? parent?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? bubble
        return ColorWindowPlacement.frame(bubble: bubble, size: size, visible: visible)
    }
}

/// Key while it is used — Liquid Glass needs that to draw its active look — but never the main window
private final class ColorWindowPanel: NSPanel {
    override var canBecomeMain: Bool { false }
}

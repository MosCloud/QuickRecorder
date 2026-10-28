//
//  ColorWindow.swift
//  QuickRecorder
//
//  The custom background colour window (#117). It opens from the Options bubble's Custom swatch, sits beside the
//  bubble, and stays while it is used — clicking in it or in the system colour panel keeps the bubble open.
//
//  It never takes key. A key window here would drop the selector's own key look and draw a dark rim around the
//  capsule's Liquid Glass, the way the floating capsule avoids it; so the panel cannot become key and uses the blur
//  material instead of glass.
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
    private var closeObserver: NSObjectProtocol?

    var isOpen: Bool { panel?.isVisible == true }

    /// The bubble reports its view; where it is gets measured when the window opens, not during its scale-in (#105)
    func note(view: NSView) {
        bubbleView = view
        if let panel { panel.setFrame(place(for: panel), display: true) }
    }

    func show() {
        guard let view = bubbleView, let window = view.window else { return }
        parent = window
        if let panel {
            panel.setFrame(place(for: panel), display: true)
            panel.orderFront(nil)
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
        panel.orderFront(nil)
        self.panel = panel
        CapsuleBubbles.shared.register(hitArea: panel.contentView)

        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                              queue: .main) { _ in
            MainActor.assumeIsolated { ColorWindow.shared.close() }
        }
    }

    func close() {
        guard let panel else { return }
        // The system panel belongs to this window: it goes with it rather than outliving it
        if NSColorPanel.shared.isVisible { NSColorPanel.shared.orderOut(nil) }
        parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
        CapsuleBubbles.shared.register(hitArea: nil)
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
    }

    /// Where the bubble is now, in screen coordinates with the origin at the bottom left
    private var bubble: CGRect? {
        guard let view = bubbleView, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
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

/// Not key, not main: the selector's window keeps both, and its Liquid Glass keeps its active look
private final class ColorWindowPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

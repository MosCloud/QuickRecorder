//
//  MenuBarPanelWindow.swift
//  QuickRecorder
//
//  The menu bar panel's window (#179, #181). NSPopover brought two problems the moment the panel stopped activating the
//  app: its glass is private and brightens when the app comes forward, and its window can't become key while the app is
//  in the background, so Esc went to the app in front instead. A borderless nonactivating NSPanel takes the click
//  without activating the app and can take the keys anyway — the same combination the area selector's window uses
//  (#170). Its material, arrow, corners and shadow are drawn here because the popover's are private.
//

import AppKit
import QuartzCore

/// The panel's window: borderless and nonactivating, able to become key while the app stays in the background
final class MenuBarPanelWindow: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc, for when the key monitor doesn't see the event first
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

/// The panel's shape and material: a rounded body with an arrow at the top edge, clipped together, so the arrow shows
/// the same glass as the body the way the popover's did
final class MenuBarPanelView: NSView {
    /// The reveal animation's mask: the body and the arrow, both opaque, so their union is the panel's shape
    let maskLayer = CALayer()
    private let bodyLayer = CALayer()
    private let hitPath = CGMutablePath()
    private let background = NSGlassEffectView()

    init(size: CGSize, arrowCentre: CGFloat) {
        super.init(frame: CGRect(origin: .zero, size: size))
        wantsLayer = true
        background.frame = bounds
        background.style = .regular
        background.cornerRadius = MenuBarPanelPlacement.cornerRadius
        // A touch darker than the glass's own tint, which is the popover's darkness over the same content (#179)
        background.tintColor = NSColor.black.withAlphaComponent(0.2)
        addSubview(background)
        // The popover's corners were continuous, and a plain corner radius doesn't reach as far in as they did
        maskLayer.masksToBounds = true
        let body = CGRect(x: 0, y: 0, width: size.width, height: size.height - MenuBarPanelPlacement.arrowHeight)
        bodyLayer.frame = body
        bodyLayer.backgroundColor = NSColor.black.cgColor
        bodyLayer.cornerRadius = MenuBarPanelPlacement.cornerRadius
        bodyLayer.cornerCurve = .continuous
        let arrow = Self.arrow(size: size, centre: arrowCentre)
        let arrowLayer = CAShapeLayer()
        arrowLayer.fillColor = NSColor.black.cgColor
        arrowLayer.path = arrow
        maskLayer.addSublayer(bodyLayer)
        maskLayer.addSublayer(arrowLayer)
        layer?.mask = maskLayer
        hitPath.addRoundedRect(in: body, cornerWidth: MenuBarPanelPlacement.cornerRadius,
                               cornerHeight: MenuBarPanelPlacement.cornerRadius)
        hitPath.addPath(arrow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The arrow alone: the body's corners are the layer's, so the two can be rounded differently
    static func arrow(size: CGSize, centre: CGFloat) -> CGPath {
        let halfArrow = MenuBarPanelPlacement.arrowWidth / 2
        let base = size.height - MenuBarPanelPlacement.arrowHeight
        let path = CGMutablePath()
        path.move(to: CGPoint(x: centre - halfArrow, y: base))
        path.addLine(to: CGPoint(x: centre, y: size.height))
        path.addLine(to: CGPoint(x: centre + halfArrow, y: base))
        path.closeSubpath()
        return path
    }

    /// A click outside the shape falls through: the menu bar under the arrow, the app behind the rounded corners
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard hitPath.contains(local) else { return nil }
        return super.hitTest(point)
    }
}

/// Shows and closes the panel, and keeps what it must while it is up: the click that closes it, the Esc that closes it,
/// and the App Nap activity that keeps the reveal at full rate (#176, #177)
@MainActor
final class MenuBarPanelController: NSObject, NSWindowDelegate {
    private(set) var window: MenuBarPanelWindow?
    private var outsideClick: Any?
    private var escape: Any?
    private var activity: NSObjectProtocol?
    private var closing = false

    var isShown: Bool { window?.isVisible == true }

    func show(relativeTo button: NSStatusBarButton, content: NSView) {
        guard window == nil else { return }
        guard let itemWindow = button.window, let screen = itemWindow.screen ?? NSScreen.main else { return }
        content.layoutSubtreeIfNeeded()
        let body = content.fittingSize
        let itemRect = itemWindow.convertToScreen(button.convert(button.bounds, to: nil))
        // The placement works in the coordinates CGWindowList reports, the origin at the top left
        let cut = screen.frame.maxY - screen.visibleFrame.maxY
        // The popover's arrow met the item's visible bottom edge, 3 pt above the status button's own bottom edge (the
        // button is 7 pt taller than the item it draws). Measured from the popover this replaces, so the panel opens
        // where the owner last saw it.
        let item = CGRect(x: itemRect.minX, y: screen.frame.maxY - itemRect.maxY - 3,
                          width: itemRect.width, height: itemRect.height)
        let visible = CGRect(x: screen.visibleFrame.minX, y: cut,
                             width: screen.visibleFrame.width, height: screen.visibleFrame.height)
        let placed = MenuBarPanelPlacement.place(content: body, below: item, in: visible)
        let frame = CGRect(x: placed.frame.minX, y: screen.frame.maxY - placed.frame.maxY,
                           width: placed.frame.width, height: placed.frame.height)

        let window = MenuBarPanelWindow(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.delegate = self
        window.onEscape = { [weak self] in self?.close() }

        let view = MenuBarPanelView(size: frame.size, arrowCentre: placed.arrowCentre)
        content.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height - MenuBarPanelPlacement.arrowHeight)
        view.addSubview(content)
        window.contentView = view

        self.window = window
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        animateIn(window, view: view)
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Menu bar panel")
        // A transient popover only dismissed itself while its app was in front, so the click that closes it is watched
        // here instead (#176)
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        // The panel is key, so Esc arrives here even while the app stays in the background (#181). The device picker
        // the panel opens doesn't take the keys, so Esc closes the panel and the picker with it.
        escape = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, !event.isARepeat else { return event }
            let consumed = MainActor.assumeIsolated { self?.closeOnEscape() ?? false }
            return consumed ? nil : event
        }
    }

    func close() {
        guard let window, let view = window.contentView as? MenuBarPanelView, !closing else { return }
        closing = true
        animateOut(view, duration: 0.15)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { window.close() }
        }
    }

    /// Esc while the panel is key: closes it and stops the event going any further
    private func closeOnEscape() -> Bool {
        guard window?.isKeyWindow == true, !closing else { return false }
        close()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if let escape {
            NSEvent.removeMonitor(escape)
            self.escape = nil
        }
        if let outsideClick {
            NSEvent.removeMonitor(outsideClick)
            self.outsideClick = nil
        }
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        window = nil
        closing = false
    }

    /// The panel is revealed from its top edge downwards, the arrow first, and covered back up from the bottom (#177).
    /// The mask is a layer of our own: AppKit manages the frame view's transform, and its translation was dropped.
    private func animateIn(_ window: NSWindow, view: MenuBarPanelView) {
        view.layoutSubtreeIfNeeded()
        guard let layer = view.layer else { return }
        let w = view.bounds.width, h = view.bounds.height
        let mask = view.maskLayer
        mask.anchorPoint = CGPoint(x: 0.5, y: 1)
        mask.position = CGPoint(x: w / 2, y: h)
        mask.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        layer.mask = mask
        // The strip that is shown grows from the top edge down: its origin travels with it, so the shape is revealed
        // from the arrow down rather than sliding in from the bottom
        let shown = CGRect(x: 0, y: 0, width: w, height: h)
        let collapsed = CGRect(x: 0, y: h, width: w, height: 0)
        let grow = CABasicAnimation(keyPath: "bounds")
        grow.fromValue = collapsed
        grow.toValue = shown
        grow.duration = 0.2
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        mask.add(grow, forKey: "wipe")
        // The window shadow follows the mask as it grows (a window capture mid-reveal put it on the visible strip's
        // edge), so the end of the reveal needs no invalidateShadow()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    /// The closing half: the bottom edge rises back towards the item (#177)
    private func animateOut(_ view: MenuBarPanelView, duration: CFTimeInterval) {
        guard let mask = view.layer?.mask else { return }
        let shown = mask.bounds
        let collapsed = CGRect(x: 0, y: shown.height, width: shown.width, height: 0)
        mask.bounds = collapsed
        let shrink = CABasicAnimation(keyPath: "bounds")
        shrink.fromValue = shown
        shrink.toValue = collapsed
        shrink.duration = duration
        shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
        mask.add(shrink, forKey: "wipe")
    }
}

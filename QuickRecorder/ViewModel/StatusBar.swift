//
//  StatusBar.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI
import QuartzCore
import KeyboardShortcuts

/// Recording started or stopped, or a setting about the controls changed: refresh the menu bar item and the capsule.
func updateStatusBar() {
    DispatchQueue.main.async { RecordingControls.shared.sync() }
}

/// The menu bar item: the app icon opening the main panel while idle, "● timer" opening a native menu while recording.
/// Native controls only: macOS 27 delivers every click on a status item at its center, so SwiftUI buttons hosted inside one stop working.
@MainActor
final class MenuBarItem: NSObject, NSMenuDelegate, NSPopoverDelegate {
    private enum Mode: Equatable { case idle, recording(RecordingKind) }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panelPopover = NSPopover()
    private let menu = NSMenu()
    private let headerItem = NSMenuItem()
    private var pauseItem: NSMenuItem?
    private var deviceItem: NSMenuItem?
    private var mode: Mode?
    private var isMenuOpen = false
    private var shownPaused: Bool?
    /// The click in another app that closes the panel: a transient popover doesn't hear it while its app is in the back
    private var outsideClick: Any?
    /// The close animation is running: another click must not start it again
    private var closing = false
    /// The panel keeps the app out of App Nap while it is up, so the animation runs at full rate (#177)
    private var activity: NSObjectProtocol?

    var button: NSStatusBarButton? { item.button }

    /// The item is meant to show but can't be seen: the notch pushed it out, or a full-screen app hides the menu bar.
    var isHidden: Bool {
        guard item.isVisible, let window = item.button?.window else { return false }
        return !window.occlusionState.contains(.visible)
    }

    override init() {
        super.init()
        item.isVisible = false
        item.button?.setAccessibilityLabel("QuickRecorder")
        // The panel closes itself, always through the same animation: a transient popover would also close on its own,
        // without it, when the app happens to be in front (#177)
        panelPopover.behavior = .applicationDefined
        panelPopover.delegate = self
        // The panel animates itself, the way a menu bar panel does, instead of the popover's spring (#177)
        panelPopover.animates = false
        menu.delegate = self
        menu.autoenablesItems = false
        headerItem.isEnabled = false
    }

    func showIdle(_ visible: Bool) {
        if mode != .idle {
            mode = .idle
            item.menu = nil
            if let button = item.button {
                button.title = ""
                button.imagePosition = .imageOnly
                button.image = NSImage(systemSymbolName: "dot.circle.and.hand.point.up.left.fill", accessibilityDescription: "QuickRecorder")?
                    .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
                button.target = self
                button.action = #selector(togglePanel)
            }
        }
        item.isVisible = visible
    }

    func showRecording(_ visible: Bool, kind: RecordingKind) {
        if mode != .recording(kind) {
            mode = .recording(kind)
            closePanel()
            buildMenu(for: kind)
            item.menu = menu
            shownPaused = nil
            if let button = item.button {
                button.target = nil
                button.action = nil
                button.imagePosition = .imageLeading
                button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            }
        }
        item.isVisible = visible
    }

    func refresh(elapsed: String, paused: Bool) {
        guard case .recording = mode else { return }
        item.button?.title = " " + elapsed
        headerItem.title = (paused ? "Paused" : "Recording").local + " · " + elapsed
        // While the menu is open only the text changes: swapping images or items then disturbs its click handling
        guard !isMenuOpen, shownPaused != paused else { return }
        shownPaused = paused
        item.button?.image = paused ? symbol("pause.fill") : redDot()
        pauseItem?.title = (paused ? "Resume Recording" : "Pause Recording").local
        pauseItem?.image = symbol(paused ? "play.circle" : "pause.circle")
    }

    func closePanel() {
        guard panelPopover.isShown, !closing else { return }
        closing = true
        guard let window = panelPopover.contentViewController?.view.window,
              let content = window.contentView?.superview ?? window.contentView else {
            closing = false
            panelPopover.performClose(nil)
            return
        }
        animateOut(content, duration: 0.15)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.closing = false
                self.panelPopover.performClose(nil)
            }
        }
    }

    /// The panel grows downwards from the item and fades in; closing shrinks it back up (#177)
    private func animateIn() {
        guard let window = panelPopover.contentViewController?.view.window,
              // The whole popover (its glass and arrow, not just the content) grows, so the frame view is the one scaled
              let content = window.contentView?.superview ?? window.contentView else { return }
        window.alphaValue = 0
        content.wantsLayer = true
        if let layer = content.layer {
            let start = entranceTransform(of: content)
            layer.transform = start
            let grow = CABasicAnimation(keyPath: "transform")
            grow.fromValue = start
            grow.toValue = CATransform3DIdentity
            grow.duration = 0.2
            grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(grow, forKey: "grow")
            layer.transform = CATransform3DIdentity
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    /// The transform that scales the panel down with its top edge in place: AppKit owns the anchor point of a
    /// view-backed layer, so it is not touched here; the scaling point is moved to the top middle instead (#177)
    private func entranceTransform(of content: NSView) -> CATransform3D {
        let w = content.bounds.width, h = content.bounds.height
        return CATransform3DConcat(
            CATransform3DMakeTranslation(w / 2, h, 0),
            CATransform3DConcat(CATransform3DMakeScale(0.75, 0.75, 1),
                                CATransform3DMakeTranslation(-w / 2, -h, 0)))
    }

    /// The closing half of the entrance: the bottom edge rises back towards the item (#177)
    private func animateOut(_ content: NSView, duration: CFTimeInterval) {
        guard let layer = content.layer else { return }
        let end = entranceTransform(of: content)
        let shrink = CABasicAnimation(keyPath: "transform")
        shrink.fromValue = CATransform3DIdentity
        shrink.toValue = end
        shrink.duration = duration
        shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
        layer.add(shrink, forKey: "shrink")
        layer.transform = end
    }

    @objc private func togglePanel() {
        guard let button = item.button else { return }
        if panelPopover.isShown { closePanel(); return }
        // Before the panel closes the other windows, so the main panel doesn't take that as backing out and close it in turn
        MainPanelReturn.shared.menuBarPanelOpened()
        let panel = NSHostingController(rootView: MenuBarPanel { [weak self] in self?.closePanel() }.onAppear { closeAllWindow() })
        panel.sizingOptions = [.preferredContentSize]
        panelPopover.contentViewController = panel
        panelPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // A click on the panel used to bring the app forward, which brightened the popover's material for no reason
        // (#179): a nonactivating window takes the click without activating the app

        animateIn()
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Menu bar panel")
        // The panel is up: close it on any click outside, and ask for the front so it takes the keys. A transient
        // popover only dismisses itself while its app is in front, and a status item's click doesn't always put it
        // there; the click monitor works either way (#176). The activation is best effort: macOS usually refuses one
        // asked for by a status item's click.
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let outsideClick {
            NSEvent.removeMonitor(outsideClick)
            self.outsideClick = nil
        }
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    private func buildMenu(for kind: RecordingKind) {
        menu.removeAllItems()
        pauseItem = nil
        deviceItem = nil
        menu.addItem(headerItem)
        menu.addItem(.separator())
        menu.addItem(menuItem("Stop Recording", "stop.circle", hotkey: .stop, #selector(stop)))
        if kind != .device {
            pauseItem = menuItem("Pause Recording", "pause.circle", hotkey: .pauseResume, #selector(togglePause))
            menu.addItem(pauseItem!)
        }
        switch kind {
        case .video:
            menu.addItem(.separator())
            menu.addItem(menuItem("Camera…", "camera", hotkey: nil, #selector(camera)))
            menu.addItem(menuItem("Save Current Frame", "camera.viewfinder", hotkey: .saveFrame, #selector(saveFrame)))
        case .device:
            menu.addItem(.separator())
            deviceItem = menuItem("Show iDevice Window", "apps.ipad", hotkey: nil, #selector(toggleDeviceWindow))
            menu.addItem(deviceItem!)
        case .audio:
            break
        }
    }

    private func menuItem(_ title: String, _ symbolName: String, hotkey: KeyboardShortcuts.Name?, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title.local, action: action, keyEquivalent: "")
        item.target = self
        item.image = symbol(symbolName)
        // Shows the user's global hotkey; KeyboardShortcuts handles the key itself while the menu is open
        if let hotkey { item.setShortcut(for: hotkey) }
        return item
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func redDot() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .regular).applying(.init(paletteColors: [.systemRed]))
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Recording".local)?.withSymbolConfiguration(config)
        image?.isTemplate = false
        return image
    }

    func menuWillOpen(_ menu: NSMenu) {
        deviceItem?.state = deviceWindow.isVisible ? .on : .off
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        RecordingControls.shared.refresh()
    }

    @objc private func stop() { RecordingControls.shared.stop() }
    @objc private func togglePause() { RecordingControls.shared.togglePause() }
    @objc private func saveFrame() { SCContext.saveFrame = true }
    @objc private func toggleDeviceWindow() { RecordingControls.shared.toggleDeviceWindow() }

    @objc private func camera() {
        guard let button = item.button else { return }
        RecordingControls.shared.showCamera(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

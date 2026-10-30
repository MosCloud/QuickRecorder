//
//  StatusBar.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI
import KeyboardShortcuts

/// Recording started or stopped, or a setting about the controls changed: refresh the menu bar item and the capsule.
func updateStatusBar() {
    DispatchQueue.main.async { RecordingControls.shared.sync() }
}

/// The menu bar item: the app icon opening the main panel while idle, "● timer" opening a native menu while recording.
/// Native controls only: macOS 27 delivers every click on a status item at its center, so SwiftUI buttons hosted inside one stop working.
@MainActor
final class MenuBarItem: NSObject, NSMenuDelegate {
    private enum Mode: Equatable { case idle, recording(RecordingKind) }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = MenuBarPanelController()
    private let menu = NSMenu()
    private let headerItem = NSMenuItem()
    private var pauseItem: NSMenuItem?
    private var deviceItem: NSMenuItem?
    private var mode: Mode?
    private var isMenuOpen = false
    private var shownPaused: Bool?

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
                button.image = Self.idleIcon()
                button.target = self
                button.action = #selector(togglePanel)
            }
        }
        item.isVisible = visible
    }

    /// The menu bar's idle icon (#186): `record.circle`'s ring with the app icon's square in the middle. Drawn as a
    /// template image, so the menu bar tints it for a light or a dark bar by itself.
    private static func idleIcon() -> NSImage {
        let side = MenuBarIcon.box
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let centre = side / 2
            let radius = MenuBarIcon.ringPathRadius
            let ring = NSBezierPath(ovalIn: NSRect(x: centre - radius, y: centre - radius,
                                                   width: radius * 2, height: radius * 2))
            ring.lineWidth = MenuBarIcon.ringLineWidth
            NSColor.black.setStroke()
            ring.stroke()

            let half = MenuBarIcon.squareSide / 2
            let square = NSBezierPath(roundedRect: NSRect(x: centre - half, y: centre - half,
                                                          width: half * 2, height: half * 2),
                                      xRadius: MenuBarIcon.squareCornerRadius,
                                      yRadius: MenuBarIcon.squareCornerRadius)
            NSColor.black.setFill()
            square.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "QuickRecorder"
        return image
    }

    func showRecording(kind: RecordingKind) {
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
        item.isVisible = true
    }

    /// The timer stays off the menu bar this recording: leave the item alone. Clearing it first would still draw the
    /// change for a frame, so nothing is touched (#192).
    func stayHidden() {
        item.isVisible = false
    }

    func refresh(elapsed: String, paused: Bool) {
        // A hidden item has no title to keep up to date, and writing one would show it (#192)
        guard case .recording = mode, item.isVisible else { return }
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
        panel.close()
    }

    @objc private func togglePanel() {
        guard let button = item.button else { return }
        if panel.isShown { closePanel(); return }
        // Before the panel closes the other windows, so the main panel doesn't take that as backing out and close it in turn
        MainPanelReturn.shared.menuBarPanelOpened()
        let content = NSHostingView(rootView: MenuBarPanel { [weak self] in self?.closePanel() }
            .onAppear { closeAllWindow() })
        panel.show(relativeTo: button, content: content)
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

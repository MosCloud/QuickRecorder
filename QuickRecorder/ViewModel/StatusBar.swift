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
    private let panelPopover = NSPopover()
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
        panelPopover.behavior = .transient
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
        if panelPopover.isShown { panelPopover.performClose(nil) }
    }

    @objc private func togglePanel() {
        guard let button = item.button else { return }
        if panelPopover.isShown { panelPopover.performClose(nil); return }
        panelPopover.contentViewController = NSHostingController(rootView: ContentViewNew().onAppear { closeAllWindow() })
        panelPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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

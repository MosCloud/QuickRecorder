//
//  RecordingControls.swift
//  QuickRecorder
//
//  Keeps the menu bar item and the notch capsule in step with the recording.
//

import SwiftUI

/// Which controls a recording offers.
enum RecordingKind {
    /// Screen, area, window or app: pause and camera.
    case video
    /// System audio only: pause, no camera.
    case audio
    /// iPhone or iPad: no pause; toggles the device window instead of the camera.
    case device

    static var current: RecordingKind {
        switch SCContext.streamType {
        case .systemaudio: .audio
        case .idevice: .device
        default: .video
        }
    }
}

@MainActor
final class RecordingControls {
    static let shared = RecordingControls()

    let capsule = NotchCapsule()
    private let menuBar = MenuBarItem()
    private let cameraPopover = NSPopover()
    private var ticker: Timer?
    private var hiddenTicks = 0
    private var statusItemHidden = false

    private init() {
        cameraPopover.behavior = .transient
        SCContext.controlWindowID = capsule.windowID
    }

    /// Whether the capsule is on: the setting, or the fallback when both settings are off.
    var capsuleEnabled: Bool {
        ControlSurfaces.whileRecording(menuBar: ud.bool(forKey: "controlsMenuBar"), capsule: ud.bool(forKey: "controlsCapsule"),
                                       statusItemHidden: false).capsule
    }

    func sync() {
        MainPanelReturn.shared.recordingChanged()
        guard SCContext.streamType != nil else {
            stopTicking()
            if cameraPopover.isShown { cameraPopover.performClose(nil) }
            menuBar.showIdle(ud.bool(forKey: "showMenubar"))
            capsule.retract()
            return
        }
        let kind = RecordingKind.current
        let surfaces = ControlSurfaces.whileRecording(menuBar: ud.bool(forKey: "controlsMenuBar"), capsule: ud.bool(forKey: "controlsCapsule"),
                                                      statusItemHidden: statusItemHidden)
        menuBar.showRecording(surfaces.statusItem, kind: kind)
        if surfaces.capsule { capsule.show(kind: kind) } else { capsule.retract() }
        startTicking()
        refresh()
    }

    func refresh() {
        let elapsed = SCContext.getRecordingLength()
        menuBar.refresh(elapsed: elapsed, paused: SCContext.isPaused)
        capsule.update(elapsed: elapsed, paused: SCContext.isPaused)
    }

    func pauseChanged() {
        refresh()
        if !SCContext.isPaused { capsule.noteActivity() }
    }

    func stop() {
        if SCContext.streamType == .idevice {
            AVOutputClass.shared.stopRecording()
        } else if SCContext.stream != nil {
            SCContext.stopRecording()
        }
    }

    func togglePause() {
        guard SCContext.stream != nil, SCContext.streamType != .idevice else { return }
        SCContext.pauseRecording()
    }

    func toggleDeviceWindow() {
        if deviceWindow.isVisible { deviceWindow.close() } else { deviceWindow.orderFront(nil) }
    }

    func showCamera(relativeTo rect: NSRect, of view: NSView, preferredEdge: NSRectEdge) {
        if cameraPopover.isShown { cameraPopover.performClose(nil); return }
        cameraPopover.contentViewController = NSHostingController(rootView: CameraPopoverView { [weak self] in
            self?.cameraPopover.performClose(nil)
        })
        NSApp.activate()
        cameraPopover.show(relativeTo: rect, of: view, preferredEdge: preferredEdge)
    }

    func closeMenuBarPanel() {
        menuBar.closePanel()
    }

    private func startTicking() {
        guard ticker == nil else { return }
        // .common: keep counting while the menu is open
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
        hiddenTicks = 0
        statusItemHidden = false
    }

    private func tick() {
        refresh()
        if SCContext.autoStop != 0 && SCContext.recordingElapsed() / 60 >= Double(SCContext.autoStop) {
            stop()
            return
        }
        // Wait for two ticks in a row, so the item isn't taken for hidden while it's still appearing
        hiddenTicks = menuBar.isHidden ? hiddenTicks + 1 : 0
        if (hiddenTicks >= 2) != statusItemHidden {
            statusItemHidden.toggle()
            sync()
        }
    }
}

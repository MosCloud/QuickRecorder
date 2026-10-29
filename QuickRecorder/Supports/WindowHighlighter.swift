//
//  WindowHighlighter.swift
//  Topit
//
//  Created by apple on 2024/11/26.
//

import SwiftUI
import ScreenCaptureKit

/// What the pointer is over while a window is being picked: the window that would be recorded
struct PickTarget: Equatable {
    var id: UInt32
    /// Global, in AppKit's bottom-left coordinates
    var frame: CGRect
    var app: String
    var title: String
}

/// Published from the mouse monitors, which run on the main queue
final class PickState: ObservableObject {
    @Published var target: PickTarget?
}

/// One screen's cover while a window is being picked (#115): the window under the pointer stays as it is — the area
/// selector's language, frost outside and a cut-out inside — with a lit edge, the fine corner marks, and its name on
/// top. A click picks it; Esc leaves by the covers' own `cancelOperation`.
struct WindowPickCover: View {
    @ObservedObject var state: PickState
    /// This screen's frame, AppKit's coordinates
    let screen: CGRect
    let notch: CGRect?
    /// A flat shade, not the area selector's blurred picture: a window is picked, not drawn, and no screen capture is
    /// needed for it (#115)
    var veil: Double = 0.35
    let pick: (UInt32) -> Void

    /// The target as this cover draws it: the screen's top-left corner as the origin
    private var hole: CGRect? {
        guard let t = state.target else { return nil }
        let r = CGRect(x: t.frame.minX - screen.minX, y: screen.maxY - t.frame.maxY,
                       width: t.frame.width, height: t.frame.height)
        return r.intersects(CGRect(origin: .zero, size: screen.size)) ? r : nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: geo.size))
                    if let hole { p.addRect(hole) }
                }
                .fill(Color.black.opacity(veil), style: FillStyle(eoFill: true))

                if let hole, let t = state.target {
                    Path(hole.insetBy(dx: 0.5, dy: 0.5)).stroke(Color.black.opacity(0.25), lineWidth: 1)
                    Path(hole.insetBy(dx: -0.5, dy: -0.5)).stroke(Color.white.opacity(0.8), lineWidth: 1)
                    ForEach(AreaMarkStyle.corners, id: \.self) { c in
                        CornerMark(rect: hole, corner: c, length: 18)
                            .stroke(AreaMarkStyle.color(.dark), style: StrokeStyle(lineWidth: AreaMarkStyle.width, lineCap: .round, lineJoin: .round))
                            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 0.5)
                    }
                    Text(verbatim: "\(t.app) · \(Int(hole.width)) × \(Int(hole.height))")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.regularMaterial).environment(\.controlActiveState, .active))
                        .fixedSize()
                        .position(x: hole.midX, y: tagY(hole))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if let t = state.target { pick(t.id) } }
        }
        .ignoresSafeArea()
    }

    /// Just inside the window's top edge, and below the notch when that is where it would be (#110's rule)
    private func tagY(_ hole: CGRect) -> CGFloat {
        let top = hole.minY + 22
        guard let notch, notch.maxY + 22 > top else { return top }
        return min(notch.maxY + 22, hole.maxY - 16)
    }
}

class WindowHighlighter {
    static let shared = WindowHighlighter()
    var mouseMonitor: Any?
    var mouseMonitorL: Any?
    var targetWindowID: Int?
    /// What the covers draw; nil when the pointer is over nothing worth picking
    let state = PickState()
    var Mode: Int = 1
    /// The capsule shown for the clicked window, at the bottom of it
    var capsule: FloatingCapsulePanel?

    /// The window was clicked: its capsule floats at its bottom, over the highlight (#79)
    @MainActor
    func chose(window: SCWindow, display: SCDisplay) {
        // The mask's press fires on every move of a drag: one capsule per choice
        guard capsule == nil else { return }
        stopMouseMonitor()
        let screen = display.nsScreen
        let frame = state.target?.frame ?? screen?.visibleFrame ?? .zero
        let visible = screen?.visibleFrame ?? frame
        capsule = FloatingCapsulePanel.show(
            SelectorCapsule(leading: [CapsuleLeading(symbol: "xmark.circle", label: "Close".local, action: { [weak self] in self?.back() })],
                            screen: screen) { [weak self] autoStop in
                self?.startRecording(window: window, display: display, autoStop: autoStop)
            },
            title: "Start Recording".local, centerX: frame.midX, bottom: max(frame.minY + 20, visible.minY + 20), within: visible)
        capsule?.onCancel = { [weak self] in self?.back() }
    }

    @MainActor
    func cancel() {
        capsule?.close()
        capsule = nil
        state.target = nil
    }

    /// Back one step, whichever way the picker is left: Esc while pointing, or Close on the picked window's capsule
    /// — both return to the picker that opened it, rather than closing the flow and bringing the main panel back
    /// (#116). 「窗口范围」 comes back as the area selector, with the rectangle it had (#113); the window selector's
    /// own point-and-select comes back as the window selector.
    @MainActor
    func back() {
        let mode = Mode
        cancel()
        stopMouseMonitor()
        DispatchQueue.main.async {
            switch mode {
            case 2:
                AppDelegate.shared.showAreaSelector()
            default:
                AppDelegate.shared.showWindowSelector()
            }
        }
    }

    func startRecording(window: SCWindow, display: SCDisplay, autoStop: TimeInterval) {
        capsule = nil
        closeAllWindow()
        let appDelegate = AppDelegate.shared
        switch Mode {
        case 2:
            guard let nsScreen = display.nsScreen else { return }
            let area = CGRectTransform(cgRect: window.frame)
            SCContext.screenArea = NSRect(x: area.origin.x - nsScreen.frame.minX, y: area.origin.y - nsScreen.frame.minY, width:area.width, height: area.height)
            appDelegate.showAreaOutline(area)
            appDelegate.countdownAndRecord(type: "area", screen: display, autoStop: autoStop)
        default:
            appDelegate.countdownAndRecord(type: "window", screen: display, windows: [window], autoStop: autoStop)
        }
    }
    
    func registerMouseMonitor(mode: Int = 1) {
        closeAllWindow()
        Mode = mode
        for screen in NSScreen.screens {
            let cover = EscPanel(contentRect: screen.frame, styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
            let host = NSHostingView(rootView: WindowPickCover(
                state: state, screen: screen.frame, notch: screen.notch,
                pick: { [weak self] id in MainActor.assumeIsolated { self?.pick(id: id) } }
            ))
            host.safeAreaRegions = []
            cover.contentView = host
            cover.level = .statusBar
            cover.sharingType = .none
            cover.backgroundColor = .clear
            cover.isReleasedWhenClosed = false
            cover.collectionBehavior = [.canJoinAllSpaces, .stationary]
            cover.title = "Screen Cover"
            cover.alphaValue = 0
            cover.orderFront(self)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                cover.animator().alphaValue = 1
            }
        }
        // Esc goes to the key window, and until the pointer is over a window there is no highlight to take it: the
        // cover under the pointer does, so Esc works as soon as point-select opens (#133)
        let pointer = NSEvent.mouseLocation
        let target = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        NSApp.windows.first { $0.title == "Screen Cover" && $0.frame == target?.frame }?.makeKeyAndOrderFront(nil)
        
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
                MainActor.assumeIsolated { self.updateMask() }
            }
        }
        if mouseMonitorL == nil {
            mouseMonitorL = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
                MainActor.assumeIsolated { self.updateMask() }
                return event
            }
        }
    }
        
    func stopMouseMonitor() {
        DispatchQueue.main.async {
            for w in NSApp.windows.filter({ $0.title == "Screen Cover" }) { w.close() }
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = mouseMonitorL {
            NSEvent.removeMonitor(monitor)
            mouseMonitorL = nil
        }
    }
    
    @MainActor
    func updateMask() {
        guard let targetWindow = getWindowUnderMouse(),
              let app = targetWindow["kCGWindowOwnerName"] as? String, app != Bundle.main.appName,
              let windowID = targetWindow["kCGWindowNumber"] as? UInt32,
              let frame = getCGWindowFrame(window: targetWindow) else {
            state.target = nil
            targetWindowID = nil
            return
        }
        guard state.target?.id != windowID else { return }
        targetWindowID = Int(windowID)
        state.target = PickTarget(id: windowID, frame: CGRectTransform(cgRect: frame), app: app,
                                  title: targetWindow["kCGWindowName"] as? String ?? "")
    }

    /// The cover was clicked: record the window it is showing, if that window is still the one under the pointer
    @MainActor
    func pick(id: UInt32) {
        guard let window = getSCWindowWithID(id), let display = SCContext.getSCDisplayWithMouse() else { return }
        chose(window: window, display: display)
    }
    
    func getWindowUnderMouse() -> [String: Any]? {
        let mousePosition = NSEvent.mouseLocation
        guard let windowList = getAllCGWindows() else { return nil }

        for window in windowList {
            guard let bounds = getCGWindowFrame(window: window) else { continue }
            if CGRectTransform(cgRect: bounds).contains(mousePosition) {
                return window
            }
        }
        return nil
    }
    
    func getAllCGWindows() -> [[String: Any]]? {
        guard var windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements,.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        windowList = windowList.filter({
            !["SystemUIServer", "Window Server"].contains($0["kCGWindowOwnerName"] as? String)
            && $0["kCGWindowAlpha"] as? NSNumber != 0
            && $0["kCGWindowLayer"] as? NSNumber == 0
        })
        
        return windowList
    }
    
    func getSCWindowWithID(_ windowID: UInt32?) -> SCWindow? {
        guard let windowID else { return nil }
        _ = SCContext.updateAvailableContentSync()
        let windows = SCContext.getWindows()
        return windows.first(where: { $0.windowID == windowID })
    }
    
    func getCGWindowFrame(window: [String: Any]) -> CGRect? {
        guard let boundsDict = window["kCGWindowBounds"] as? [String: CGFloat] else { return nil }
        let bounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        return bounds
    }
}

class EscPanel: NSPanel {
    override func cancelOperation(_ sender: Any?) {
        self.close()
        WindowHighlighter.shared.back()
    }
    override var canBecomeKey: Bool {
        return true
    }
}

func CGRectTransform(cgRect: CGRect) -> NSRect {
    let x = cgRect.origin.x
    let y = cgRect.origin.y
    let w = cgRect.width
    let h = cgRect.height
    if let main = NSScreen.screens.first(where: { $0.isMainScreen }) {
        return NSRect(x: x, y: main.frame.height - y - h, width: w, height: h)
    }
    return cgRect
}

extension View {
    func onPressGesture(perform: @escaping () -> Void) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in perform() }
        )
    }
}

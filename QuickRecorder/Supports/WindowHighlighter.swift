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
}

/// The pick in progress: what is under the pointer, what has been picked, and each screen's frosted picture (#115)
final class PickState: ObservableObject {
    @Published var hovered: PickTarget?
    /// Set once a click confirms; the covers then frost everything but it
    @Published var chosen: PickTarget?
    /// Each screen's frosted picture, taken as the pick opens: the area selector's own frost (#108)
    @Published var frost: [CGDirectDisplayID: NSImage] = [:]
    /// True from the moment the pick opens until the pointer first moves: the hint has to be seen, and the window
    /// under a pointer that hasn't moved yet would otherwise explain the pick instead (#141)
    @Published var prompting = true
}

/// One screen's cover while a window is being picked (#115). Before a window is chosen the screen is left alone and
/// only the window under the pointer is framed, the way the area selector frames an area; after the click the rest of
/// the screen takes the area selector's frost, with the chosen window cut out of it. A click picks, Esc goes back.
struct WindowPickCover: View {
    @ObservedObject var state: PickState
    /// This screen's frame, AppKit's coordinates
    let screen: CGRect
    let displayID: CGDirectDisplayID
    let notch: CGRect?
    /// What this pick is for, when it says anything at all: the window selector's point-and-select names itself, the
    /// area selector's 「窗口范围」 is already explained by the capsule that opened it (#141)
    let hint: LocalizedStringKey?
    /// The menu bar's height on this screen: the hint sits just under it, as the recording capsule does
    let menuBar: CGFloat

    /// The window to frame: the one under the pointer, or the chosen one once a click has happened
    private var subject: PickTarget? { state.chosen ?? state.hovered }

    /// It as this cover draws it: the screen's top-left corner as the origin
    private func local(_ t: PickTarget) -> CGRect {
        CGRect(x: t.frame.minX - screen.minX, y: screen.maxY - t.frame.maxY,
               width: t.frame.width, height: t.frame.height)
    }

    var body: some View {
        GeometryReader { geo in
            let hole = subject.map(local).flatMap { $0.intersects(CGRect(origin: .zero, size: geo.size)) ? $0 : nil }
            ZStack(alignment: .topLeading) {
                // A whisker of black keeps the window clickable: a fully transparent one hands the click behind it (#114)
                Color.black.opacity(1.0 / 255.0)

                if state.chosen != nil {
                    frost(geo, hole: hole)
                }

                // Nothing framed yet: say what this screen is waiting for, where a recording's capsule comes up,
                // with its material and its spring, so the two read as the same kind of thing (#141)
                if let hint, state.chosen == nil, state.hovered == nil || state.prompting {
                    VStack {
                        OverlayCapsule {
                            HStack(spacing: 8) {
                                Text(hint)
                                Text("Esc to cancel").foregroundStyle(.secondary)
                            }
                            .font(.system(size: 12))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, hintTop)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                }

                if let hole, let t = subject, !state.prompting {
                    Path(hole.insetBy(dx: 0.5, dy: 0.5)).stroke(Color.black.opacity(0.25), lineWidth: 1)
                    Path(hole.insetBy(dx: -0.5, dy: -0.5)).stroke(Color.white.opacity(0.8), lineWidth: 1)
                    ForEach(AreaMarkStyle.corners, id: \.self) { c in
                        CornerMark(rect: hole, corner: c, length: 18)
                            .stroke(AreaMarkStyle.color(.dark), style: StrokeStyle(lineWidth: AreaMarkStyle.width, lineCap: .round, lineJoin: .round))
                            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 0.5)
                    }
                    // Follows the panel material like every other pill, without the rim glass leaves (#151)
                    OverlayCapsule {
                        Text(verbatim: "\(t.app) · \(Int(hole.width)) × \(Int(hole.height))")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                    }
                    .fixedSize()
                    .position(x: hole.midX, y: tagY(hole))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                MainActor.assumeIsolated { WindowHighlighter.shared.pick() }
            }
            .animation(.spring(duration: 0.3, bounce: 0.25), value: state.hovered)
            .animation(.spring(duration: 0.3, bounce: 0.25), value: state.chosen)
        }
        .ignoresSafeArea()
    }

    /// The screen's frozen picture outside the chosen window: the same blur and tint the area selector uses (#108)
    @ViewBuilder private func frost(_ geo: GeometryProxy, hole: CGRect?) -> some View {
        if let picture = state.frost[displayID] {
            Image(nsImage: picture)
                .resizable()
                .frame(width: geo.size.width, height: geo.size.height)
                .mask {
                    Path { p in
                        p.addRect(CGRect(origin: .zero, size: geo.size))
                        if let hole { p.addRect(hole) }
                    }
                    .fill(Color.black, style: FillStyle(eoFill: true))
                }
                .transition(.opacity)
        } else {
            // Before the picture arrives: the shade is better than nothing
            Path { p in
                p.addRect(CGRect(origin: .zero, size: geo.size))
                if let hole { p.addRect(hole) }
            }
            .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))
            .transition(.opacity)
        }
    }

    /// Under the menu bar, or under the notch where there is one: the recording capsule's own place (#141)
    private var hintTop: CGFloat {
        max(menuBar, notch?.maxY ?? 0) + 6
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
    /// What the covers draw; nil when the pointer is over nothing worth picking
    let state = PickState()
    var Mode: Int = 1
    /// The capsule shown for the clicked window, at the bottom of it
    var capsule: FloatingCapsulePanel?

    /// The window was clicked: its capsule floats at its bottom, over the frosted screen (#79)
    @MainActor
    func chose(window: SCWindow, display: SCDisplay) {
        // A press fires on every move of a drag: one capsule per choice
        guard capsule == nil else { return }
        let screen = display.nsScreen
        let frame = state.chosen?.frame ?? screen?.visibleFrame ?? .zero
        let visible = screen?.visibleFrame ?? frame
        capsule = FloatingCapsulePanel.show(
            SelectorCapsule(leading: [CapsuleLeading(symbol: "xmark.circle", label: "Close".local, action: { [weak self] in self?.back() })],
                            screen: screen) { [weak self] autoStop in
                self?.startRecording(window: window, display: display, autoStop: autoStop)
            },
            title: "Start Recording".local, centerX: frame.midX, bottom: max(frame.minY + 20, visible.minY + 20), within: visible,
            level: PickerShield.above)
        capsule?.onCancel = { [weak self] in self?.back() }
    }

    @MainActor
    func cancel() {
        capsule?.close()
        capsule = nil
        state.chosen = nil
        state.hovered = nil
    }

    /// Back one step, whichever way the picker is left: Esc while pointing, or Close on the picked window's capsule
    /// — both return to the picker that opened it, rather than closing the flow and bringing the main panel back
    /// (#116). 「窗口范围」 comes back as the area selector, with the rectangle it had (#113); the window selector's
    /// own point-and-select comes back as the window selector.
    @MainActor
    func back() {
        // One level at a time: a picked window's capsule goes first, back to choosing, and only the next Esc leaves
        // the picker for the screen it came from (#115)
        if state.chosen != nil {
            capsule?.close()
            capsule = nil
            withAnimation(.easeOut(duration: 0.18)) { state.chosen = nil }
            startHoverTracking()
            return
        }
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
        // Same as the area selector: the menu bar swallows real clicks even over the covers (#163)
        PickerPresentation.begin()
        Mode = mode
        state.hovered = nil
        state.chosen = nil
        state.prompting = true
        // Last pick's pictures are gone: before the new ones arrive the covers draw nothing rather than the old screen
        state.frost = [:]
        MainActor.assumeIsolated { captureFrost() }
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let cover = EscPanel(contentRect: screen.frame, styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
            let host = NSHostingView(rootView: WindowPickCover(state: state, screen: screen.frame,
                                                               displayID: displayID, notch: screen.notch,
                                                               hint: mode == 2 ? "Select the area to record"
                                                                               : "Select a window to record",
                                                               menuBar: max(screen.frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)))
            host.safeAreaRegions = []
            cover.contentView = host
            cover.level = PickerShield.cover
            cover.sharingType = .none
            cover.backgroundColor = .clear
            cover.isReleasedWhenClosed = false
            cover.collectionBehavior = [.canJoinAllSpaces, .stationary]
            cover.title = "Screen Cover"
            cover.orderFront(self)
        }
        // Esc goes to the key window, and until the pointer is over a window there is no highlight to take it: the
        // cover under the pointer does, so Esc works as soon as point-select opens (#133)
        let pointer = NSEvent.mouseLocation
        let target = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        NSApp.windows.first { $0.title == "Screen Cover" && $0.frame == target?.frame }?.makeKeyAndOrderFront(nil)
        // Same as the area selector: the top row's clicks go to the frontmost app's menu bar until activation lands (#163)
        if let pointerCover = NSApp.windows.first(where: { $0.title == "Screen Cover" && $0.frame == target?.frame }) {
            holdActivation(while: pointerCover)
        }
        
        startHoverTracking()
    }

    /// Watches where the pointer is while a window is being chosen
    func startHoverTracking() {
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
        state.frost = [:]
        // Leaving the picker: menu bar and Dock back (#163)
        PickerPresentation.end()
        DispatchQueue.main.async {
            for w in NSApp.windows.filter({ $0.title == "Screen Cover" }) { w.close() }
        }
        stopHoverTracking()
    }

    /// Only the pointer tracking stops: the covers stay, showing the frost around the chosen window
    func stopHoverTracking() {
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
        guard state.chosen == nil else { return }
        // The pointer moved: from here the window it is over explains the pick
        if state.prompting { state.prompting = false }
        guard let targetWindow = getWindowUnderMouse(),
              let app = targetWindow["kCGWindowOwnerName"] as? String, app != Bundle.main.appName,
              let windowID = targetWindow["kCGWindowNumber"] as? UInt32,
              let frame = getCGWindowFrame(window: targetWindow) else {
            state.hovered = nil
            return
        }
        guard state.hovered?.id != windowID else { return }
        state.hovered = PickTarget(id: windowID, frame: CGRectTransform(cgRect: frame), app: app)
    }

    /// The click: the window under the pointer is taken, everything else frosts over, and its capsule comes up
    @MainActor
    func pick() {
        guard let target = state.hovered else { return }
        state.chosen = target
        // The pointer stops choosing, but the covers stay to show the frost
        stopHoverTracking()
        guard let window = getSCWindowWithID(target.id), let display = SCContext.getSCDisplayWithMouse() else { return }
        withAnimation(.easeOut(duration: 0.18)) { chose(window: window, display: display) }
    }

    /// Each screen's frosted picture, taken while the screens still look normal: the pick frosts them only once a
    /// window is chosen (#115)
    @MainActor
    func captureFrost() {
        for screen in NSScreen.screens {
            guard let id = screen.displayID,
                  let display = SCContext.availableContent?.displays.first(where: { $0.displayID == id }) else { continue }
            Task { @MainActor in
                guard let picture = await AreaFrost.picture(of: display) else { return }
                state.frost[id] = NSImage(cgImage: picture, size: screen.frame.size)
            }
        }
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
    /// Only back one layer (#155): closing this cover first would take it away and leave the picker with nothing on
    /// screen, while `back()` stays on the layer below. Leaving the picker altogether closes every cover itself.
    override func cancelOperation(_ sender: Any?) {
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

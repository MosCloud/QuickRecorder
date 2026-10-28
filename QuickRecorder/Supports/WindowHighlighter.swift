//
//  WindowHighlighter.swift
//  Topit
//
//  Created by apple on 2024/11/26.
//

import SwiftUI
import ScreenCaptureKit

struct CoverView: View {
    var body: some View {
        Color.clear.overlay { Rectangle().stroke(.blue, lineWidth: 5) }
    }
}

struct HighlightMask: View {
    let app: String
    let title: String
    let windowID: Int
    var appDelegate = AppDelegate.shared
    @State var window: SCWindow?
    @State var display: SCDisplay?
    @State var color: Color = .blue
    @State var showSheet: Bool = false

    var body: some View {
        color
            .opacity(0.2)
            .cornerRadius(10)
            .help("\(app) - \(title)")
            .sheet(isPresented: $showSheet) {
                HStack(spacing: 4) {
                    BarButton(icon: "xmark.circle.fill", style: .gray, title: "Cancel") { showSheet = false }
                    Spacer()
                    OptionsView()
                    Spacer()
                    StartControls { autoStop in startRecording(autoStop: autoStop) }
                }
                .focusable(false)
                .frame(width: 640, height: 90)
                .padding(.horizontal, 40)
                .onDisappear {
                    if let mask = WindowHighlighter.shared.mask {
                        mask.close()
                    }
                }
            }
            .onPressGesture {
                if let w = WindowHighlighter.shared.getSCWindowWithID(UInt32(windowID)),
                   let d = SCContext.getSCDisplayWithMouse() {
                    display = d
                    window = w
                    WindowHighlighter.shared.stopMouseMonitor()
                    showSheet = true
                    return
                }
                color = .red
                withAnimation(.easeInOut(duration: 0.6)) { color = .blue }
            }
    }
    
    func startRecording(autoStop: Int) {
        closeAllWindow()
        switch WindowHighlighter.shared.Mode {
        case 2:
            guard let screen = display, let nsScreen = display?.nsScreen, var area = window?.frame else { return }
            area = CGRectTransform(cgRect: area)
            SCContext.screenArea = NSRect(x: area.origin.x - nsScreen.frame.minX, y: area.origin.y - nsScreen.frame.minY, width:area.width, height: area.height)
            appDelegate.showAreaOutline(area, margin: 3)
            appDelegate.countdownAndRecord(type: "area", screen: screen, autoStop: autoStop)
        default:
            if let d = display, let w = window {
                appDelegate.countdownAndRecord(type: "window", screen: d, windows: [w], autoStop: autoStop)
            }
        }
    }
}

class WindowHighlighter {
    static let shared = WindowHighlighter()
    var mouseMonitor: Any?
    var mouseMonitorL: Any?
    var targetWindowID: Int?
    var mask: EscPanel?
    var Mode: Int = 1
    
    func registerMouseMonitor(mode: Int = 1) {
        closeAllWindow()
        Mode = mode
        DispatchQueue.main.async {
            var message = ""
            var id = ""
            switch mode {
            case 2:
                id = "qr.how-to-select.note2"
                message = "Click on a window to select its area\nor press Esc to cancel.".local
            default:
                message = "Click the window you want to record\nor press Esc to cancel.".local
                id = "qr.how-to-select.note"
            }
            tips(message, id: id)
        }
        
        for screen in NSScreen.screens {
            let cover = EscPanel(contentRect: screen.frame, styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
            cover.contentView = NSHostingView(rootView: CoverView())
            cover.level = .statusBar
            cover.sharingType = .none
            cover.backgroundColor = .clear
            cover.ignoresMouseEvents = true
            cover.isReleasedWhenClosed = false
            cover.collectionBehavior = [.canJoinAllSpaces, .stationary]
            cover.title = "Screen Cover"
            cover.orderFront(self)
        }
        
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in self.updateMask() }
        }
        if mouseMonitorL == nil {
            mouseMonitorL = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
                self.updateMask()
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
    
    func updateMask() {
        guard let targetWindow = getWindowUnderMouse() else {
            mask?.close()
            targetWindowID = nil
            return
        }
        
        if let app = targetWindow["kCGWindowOwnerName"] as? String, app != Bundle.main.appName,
           let windowID = targetWindow["kCGWindowNumber"] as? Int, targetWindowID != windowID {
            mask?.close()
            targetWindowID = windowID
            createMaskWindow(window: targetWindow)
        }
    }
    
    func createMaskWindow(window: [String: Any]) {
        guard let windowID = targetWindowID, let frame = getCGWindowFrame(window: window) else { return }
        let app = window["kCGWindowOwnerName"] as? String ?? ""
        let title = window["kCGWindowName"] as? String ?? ""
        
        mask = EscPanel(contentRect: CGRectTransform(cgRect: frame),
                        styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        let contentView = NSHostingView(rootView: HighlightMask(app: app, title: title, windowID: windowID))
        mask?.contentView = contentView
        mask?.title = "Mask Window"
        mask?.hasShadow = false
        mask?.sharingType = .none
        mask?.backgroundColor = .clear
        mask?.titleVisibility = .hidden
        mask?.isMovableByWindowBackground = false
        mask?.isReleasedWhenClosed = false
        mask?.collectionBehavior = [.canJoinAllSpaces, .transient]
        mask?.setFrame(CGRectTransform(cgRect: frame), display: true)
        mask?.order(.above, relativeTo: windowID)
        mask?.makeKey()
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
        WindowHighlighter.shared.stopMouseMonitor()
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

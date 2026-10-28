//
//  AreaSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/20.
//

import SwiftUI
import ScreenCaptureKit
import Quartz

/// The marks around an area (#97): thin square corners just outside it, white in dark mode and near-black in light
enum AreaMarkStyle {
    /// The marks' line width; they sit just outside the area, their inner side on its edge
    static let width: CGFloat = 3
    static let corners: [ResizeHandle] = [.topLeft, .topRight, .bottomRight, .bottomLeft]
    static let edges: [ResizeHandle] = [.top, .right, .bottom, .left]
    static func color(_ scheme: ColorScheme) -> Color { scheme == .dark ? .white : Color(white: 0.15) }
    static func shadow(_ scheme: ColorScheme) -> Color { .black.opacity(scheme == .dark ? 0.4 : 0.1) }
}

/// One corner's L along `rect`'s sides, in flipped coordinates
struct CornerMark: Shape {
    let rect: CGRect
    let corner: ResizeHandle
    var length: CGFloat

    var animatableData: CGFloat {
        get { length }
        set { length = newValue }
    }

    func path(in _: CGRect) -> Path {
        let c = corner.point(inFlipped: rect)
        let dx: CGFloat = corner == .topLeft || corner == .bottomLeft ? 1 : -1
        let dy: CGFloat = corner == .topLeft || corner == .topRight ? 1 : -1
        let l = min(length, rect.width / 3, rect.height / 3)
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + dy * l))
        p.addLine(to: c)
        p.addLine(to: CGPoint(x: c.x + dx * l, y: c.y))
        return p
    }
}

/// What stays around an area while it records: the area selector's corners, in a window just bigger than the area
/// so they stay out of the recording (#97)
struct AreaOutline: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { g in
            let line = CGRect(origin: .zero, size: g.size).insetBy(dx: AreaMarkStyle.width / 2, dy: AreaMarkStyle.width / 2)
            ZStack {
                ForEach(AreaMarkStyle.corners, id: \.self) { c in
                    CornerMark(rect: line, corner: c, length: 18)
                        .stroke(AreaMarkStyle.color(scheme), style: StrokeStyle(lineWidth: AreaMarkStyle.width, lineCap: .round, lineJoin: .round))
                        .shadow(color: AreaMarkStyle.shadow(scheme), radius: 1.5, y: 0.5)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// The area and the handle under the pointer or being dragged, for the marks over the frost
@MainActor
final class AreaMarksModel: ObservableObject {
    /// In the overlay's flipped coordinates
    @Published var rect = CGRect.zero
    @Published var handle = ResizeHandle.none
}

/// Over the frost (#97): its cut edge catching the light, the corners, a bar on the edge under the pointer, and the size
struct AreaMarks: View {
    @ObservedObject var model: AreaMarksModel
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { g in
            let r = model.rect
            let line = r.insetBy(dx: -AreaMarkStyle.width / 2, dy: -AreaMarkStyle.width / 2)
            let mark = AreaMarkStyle.color(scheme), shadow = AreaMarkStyle.shadow(scheme)
            ZStack(alignment: .topLeading) {
                // A hairline inside keeps the lit edge apart from light content
                Path(r.insetBy(dx: 0.5, dy: 0.5)).stroke(Color.black.opacity(0.2), lineWidth: 1)
                Path(r.insetBy(dx: -0.5, dy: -0.5)).stroke(Color.white.opacity(0.75), lineWidth: 1)
                ForEach(AreaMarkStyle.corners, id: \.self) { c in
                    let near = model.handle == c
                    CornerMark(rect: line, corner: c, length: near ? 24 : 18)
                        .stroke(mark, style: StrokeStyle(lineWidth: AreaMarkStyle.width, lineCap: .round, lineJoin: .round))
                        .shadow(color: shadow, radius: 1.5, y: 0.5)
                        .animation(.easeOut(duration: 0.15), value: near)
                }
                // The whole edge resizes; the bar only says so
                ForEach(AreaMarkStyle.edges, id: \.self) { e in
                    let shown = model.handle == e, across = e == .top || e == .bottom
                    Capsule().fill(mark)
                        .frame(width: across ? (shown ? 24 : 6) : AreaMarkStyle.width, height: across ? AreaMarkStyle.width : (shown ? 24 : 6))
                        .shadow(color: shadow, radius: 1.5, y: 0.5)
                        .opacity(shown ? 1 : 0)
                        .position(e.point(inFlipped: line))
                        .animation(.spring(duration: 0.25, bounce: 0.3), value: shown)
                }
                sizeTag(r, in: g.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func sizeTag(_ r: CGRect, in size: CGSize) -> some View {
        Text(verbatim: "\(Int(r.width)) × \(Int(r.height))")
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background {
                // Not glass: the overlay isn't the key window, and glass there draws a dark rim
                if material == .black {
                    Capsule().fill(.black)
                } else {
                    Capsule().fill(.regularMaterial).environment(\.controlActiveState, .active)
                }
            }
            .environment(\.colorScheme, material == .black ? .dark : scheme)
            .fixedSize()
            // Above the middle of the area, or just inside its top when there's no room above
            .position(x: min(max(r.midX, 60), size.width - 60), y: r.minY >= 44 ? r.minY - 24 : r.minY + 24)
    }
}

/// The frost around the area: a live blur of whatever is on screen behind the overlay (#97)
private final class FrostView: NSVisualEffectView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .fullScreenUI
        blendingMode = .behindWindow
        state = .active
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The overlay takes the mouse
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// The area's size in a bubble of the capsule: width × height, then what the recording comes out at
struct AreaSizeFields: View {
    @AppStorage("areaWidth")  private var areaWidth: Int = 600
    @AppStorage("areaHeight") private var areaHeight: Int = 450
    @AppStorage("highRes")    private var highRes: Int = 2

    var appDelegate = AppDelegate.shared
    var screen: SCDisplay!

    var body: some View {
        let scale = highRes == 2 ? Int(screen.nsScreen?.backingScaleFactor ?? 1) : 1
        HStack(spacing: 4) {
            field($areaWidth, max: screen.width)
            Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
            field($areaHeight, max: screen.height)
            Text(verbatim: "→ \(areaWidth * scale) × \(areaHeight * scale)")
                .font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .fixedSize()
    }

    private func field(_ value: Binding<Int>, max: Int) -> some View {
        TextField("", value: value, formatter: NumberFormatter())
            .onSubmit { CapsuleBubbles.shared.close() }
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(width: 46, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.quaternary))
            .onChange(of: value.wrappedValue) { _, newValue in
                if !appDelegate.isResizing {
                    value.wrappedValue = min(Swift.max(newValue, 1), max)
                    resize()
                }
            }
    }

    func resize() {
        closeAllWindow(except: "Start Recording".local)
        AppDelegate.shared.showAreaSelector(size: NSSize(width: areaWidth, height: areaHeight), noPanel: true)
    }
}

/// The area selector's capsule (#79): Close, Window Area and Resize first, then what every selector's capsule has
struct AreaSelector: View {
    @State private var nsWindow: NSWindow?
    
    var screen: SCDisplay!
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        SelectorCapsule(leading: [
            CapsuleLeading(symbol: "xmark.circle", label: "Close".local, action: { nsWindow?.close() }),
            CapsuleLeading(symbol: "macwindow", label: "Window Area".local, action: selectWindowArea),
            CapsuleLeading(symbol: "viewfinder", label: "Resize".local, bubble: AnyView(AreaSizeFields(screen: screen))),
        ], screen: screen.nsScreen, showsBackground: false) {
            startRecording(autoStop: $0)
        }
        .background(WindowAccessor(onWindowOpen: { w in nsWindow = w }, onWindowClose: {
            DispatchQueue.main.async {
                for w in NSApp.windows.filter({ $0.title == "Area Selector".local }) { w.close() }
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
                appDelegate.stopGlobalMouseMonitor()
            }
        }))
    }

    private func selectWindowArea() {
        nsWindow?.close()
        for w in NSApp.windows.filter({$0.title == "Area Selector".local }) { w.close() }
        appDelegate.stopGlobalMouseMonitor()
        WindowHighlighter.shared.registerMouseMonitor(mode: 2)
    }
    
    func startRecording(autoStop: TimeInterval) {
        closeAllWindow()
        appDelegate.stopGlobalMouseMonitor()
        let area = SCContext.screenArea!
        guard let nsScreen = screen.nsScreen else { return }
        appDelegate.showAreaOutline(area.offsetBy(dx: nsScreen.frame.minX, dy: nsScreen.frame.minY))
        appDelegate.countdownAndRecord(type: "area", screen: screen, autoStop: autoStop)
    }
}

class ScreenshotOverlayView: NSView {
    @AppStorage("areaWidth") private var areaWidth: Int = 600
    @AppStorage("areaHeight") private var areaHeight: Int = 450
    
    var selectionRect: NSRect? {
        didSet { layoutMarks() }
    }
    var initialLocation: NSPoint?
    var dragIng: Bool = false
    var activeHandle: ResizeHandle = .none
    var lastMouseLocation: NSPoint?
    var maxFrame: NSRect?
    var size: NSSize
    var force: Bool

    /// The frost on the four sides of the area, and over it the marks (#97)
    private let frost = (0..<4).map { _ in FrostView(frame: .zero) }
    private let marks = AreaMarksModel()
    private var eased = false

    init(frame: CGRect, size: NSSize, force: Bool) {
        self.size = size
        self.force = force
        super.init(frame: frame)
        wantsLayer = true
        frost.forEach(addSubview)
        let host = NSHostingView(rootView: AreaMarks(model: marks))
        host.safeAreaRegions = []
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        selectionRect = NSRect(x: (self.frame.width - size.width) / 2, y: (self.frame.height - size.height) / 2, width: size.width, height: size.height)
        if !force {
            let savedArea = ud.object(forKey: "savedArea") as! [String: [String: CGFloat]]
            if let name = self.window?.screen?.localizedName {
                if let area = savedArea[name] {
                    selectionRect = NSRect(x: area["x"]!, y: area["y"]!, width: area["width"]!, height: area["height"]!)
                }
            }
        }
        if self.window != nil {
            areaWidth = Int(selectionRect!.width)
            areaHeight = Int(selectionRect!.height)
            SCContext.screenArea = selectionRect
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        maxFrame = dirtyRect
    }

    // The frost and the marks only show: every click is the overlay's
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }

    /// Frost everywhere but the area, and the marks around it
    private func layoutMarks() {
        guard let r = selectionRect else { return }
        let b = bounds
        let sides = [NSRect(x: 0, y: 0, width: b.width, height: r.minY),
                     NSRect(x: 0, y: r.maxY, width: b.width, height: b.height - r.maxY),
                     NSRect(x: 0, y: r.minY, width: r.minX, height: r.height),
                     NSRect(x: r.maxX, y: r.minY, width: b.width - r.maxX, height: r.height)]
        for (view, side) in zip(frost, sides) {
            view.frame = NSRect(x: side.minX, y: side.minY, width: max(side.width, 0), height: max(side.height, 0))
        }
        marks.rect = CGRect(x: r.minX, y: b.height - r.maxY, width: r.width, height: r.height)
    }

    /// While the area moves or changes size the frost thins, so what's around it shows to line it up against
    private func ease(_ on: Bool) {
        guard on != eased else { return }
        eased = on
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            frost.forEach { $0.animator().alphaValue = on ? 0.25 : 1 }
        }
    }

    /// Where each handle takes the pointer: a square at a corner, the rest of the edge between them
    private func zone(_ handle: ResizeHandle, of r: NSRect) -> NSRect {
        let corner: CGFloat = 28, edge: CGFloat = 14
        func square(_ x: CGFloat, _ y: CGFloat) -> NSRect { NSRect(x: x - corner / 2, y: y - corner / 2, width: corner, height: corner) }
        let across = NSRect(x: r.minX + corner / 2, y: 0, width: max(r.width - corner, 0), height: edge)
        let along = NSRect(x: 0, y: r.minY + corner / 2, width: edge, height: max(r.height - corner, 0))
        switch handle {
        case .topLeft: return square(r.minX, r.maxY)
        case .topRight: return square(r.maxX, r.maxY)
        case .bottomRight: return square(r.maxX, r.minY)
        case .bottomLeft: return square(r.minX, r.minY)
        case .top: return across.offsetBy(dx: 0, dy: r.maxY - edge / 2)
        case .bottom: return across.offsetBy(dx: 0, dy: r.minY - edge / 2)
        case .left: return along.offsetBy(dx: r.minX - edge / 2, dy: 0)
        case .right: return along.offsetBy(dx: r.maxX - edge / 2, dy: 0)
        case .none: return .zero
        }
    }

    func handleForPoint(_ point: NSPoint) -> ResizeHandle {
        guard let rect = selectionRect else { return .none }
        return ResizeHandle.allCases.first { $0 != .none && zone($0, of: rect).contains(point) } ?? .none
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // Always: the capsule's panel is the key window, not this one
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { pointerMoved(event) }
    override func cursorUpdate(with event: NSEvent) { pointerMoved(event) }

    private func pointerMoved(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let handle = handleForPoint(point)
        if marks.handle != handle { marks.handle = handle }
        cursor(for: handle, at: point).set()
    }

    /// Resizing at the edges and corners, a hand inside the area, a crosshair to draw a new one outside it
    private func cursor(for handle: ResizeHandle, at point: NSPoint) -> NSCursor {
        switch handle {
        case .none:
            guard let r = selectionRect, r.contains(point) else { return .crosshair }
            return dragIng ? .closedHand : .openHand
        case .topLeft: return .frameResize(position: .topLeft, directions: .all)
        case .top: return .frameResize(position: .top, directions: .all)
        case .topRight: return .frameResize(position: .topRight, directions: .all)
        case .right: return .frameResize(position: .right, directions: .all)
        case .bottomRight: return .frameResize(position: .bottomRight, directions: .all)
        case .bottom: return .frameResize(position: .bottom, directions: .all)
        case .bottomLeft: return .frameResize(position: .bottomLeft, directions: .all)
        case .left: return .frameResize(position: .left, directions: .all)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        initialLocation = location
        lastMouseLocation = location
        activeHandle = handleForPoint(location)
        if let rect = selectionRect, NSPointInRect(location, rect) { dragIng = true }
        AppDelegate.shared.isResizing = true
        marks.handle = activeHandle
        cursor(for: activeHandle, at: location).set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard var initialLocation = initialLocation else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        ease(true)
        if activeHandle != .none {

            // Calculate new rectangle size and position
            var newRect = selectionRect ?? CGRect.zero

            // Get last mouse location
            let lastLocation = lastMouseLocation ?? currentLocation

            let deltaX = currentLocation.x - lastLocation.x
            let deltaY = currentLocation.y - lastLocation.y

            switch activeHandle {
            case .topLeft:
                newRect.origin.x = min(newRect.origin.x + newRect.size.width - 20, newRect.origin.x + deltaX)
                newRect.size.width = max(20, newRect.size.width - deltaX)
                newRect.size.height = max(20, newRect.size.height + deltaY)
            case .top:
                newRect.size.height = max(20, newRect.size.height + deltaY)
            case .topRight:
                newRect.size.width = max(20, newRect.size.width + deltaX)
                newRect.size.height = max(20, newRect.size.height + deltaY)
            case .right:
                newRect.size.width = max(20, newRect.size.width + deltaX)
            case .bottomRight:
                newRect.origin.y = min(newRect.origin.y + newRect.size.height - 20, newRect.origin.y + deltaY)
                newRect.size.width = max(20, newRect.size.width + deltaX)
                newRect.size.height = max(20, newRect.size.height - deltaY)
            case .bottom:
                newRect.origin.y = min(newRect.origin.y + newRect.size.height - 20, newRect.origin.y + deltaY)
                newRect.size.height = max(20, newRect.size.height - deltaY)
            case .bottomLeft:
                newRect.origin.y = min(newRect.origin.y + newRect.size.height - 20, newRect.origin.y + deltaY)
                newRect.origin.x = min(newRect.origin.x + newRect.size.width - 20, newRect.origin.x + deltaX)
                newRect.size.width = max(20, newRect.size.width - deltaX)
                newRect.size.height = max(20, newRect.size.height - deltaY)
            case .left:
                newRect.origin.x = min(newRect.origin.x + newRect.size.width - 20, newRect.origin.x + deltaX)
                newRect.size.width = max(20, newRect.size.width - deltaX)
            default:
                break
            }
            self.selectionRect = newRect
            initialLocation = currentLocation // Update initial location for continuous dragging
            lastMouseLocation = currentLocation // Update last mouse location
            areaWidth = Int(selectionRect!.width)
            areaHeight = Int(selectionRect!.height)
        } else {
            if dragIng {
                dragIng = true
                // 计算移动偏移量
                let deltaX = currentLocation.x - initialLocation.x
                let deltaY = currentLocation.y - initialLocation.y

                // 更新矩形位置
                let x = self.selectionRect?.origin.x
                let y = self.selectionRect?.origin.y
                let w = self.selectionRect?.size.width
                let h = self.selectionRect?.size.height
                self.selectionRect?.origin.x = min(max(0.0, x! + deltaX), self.frame.width - w!)
                self.selectionRect?.origin.y = min(max(0.0, y! + deltaY), self.frame.height - h!)
                initialLocation = currentLocation
            } else {
                //dragIng = false
                // 创建新矩形
                guard let maxFrame = maxFrame else { return }
                let origin = NSPoint(x: max(maxFrame.origin.x, min(initialLocation.x, currentLocation.x)), y: max(maxFrame.origin.y, min(initialLocation.y, currentLocation.y)))
                var maxH = abs(currentLocation.y - initialLocation.y)
                var maxW = abs(currentLocation.x - initialLocation.x)
                if currentLocation.y < maxFrame.origin.y { maxH = initialLocation.y }
                if currentLocation.x < maxFrame.origin.x { maxW = initialLocation.x }
                let size = NSSize(width: maxW, height: maxH)
                self.selectionRect = NSIntersectionRect(maxFrame, NSRect(origin: origin, size: size))
                areaWidth = Int(selectionRect!.width)
                areaHeight = Int(selectionRect!.height)
                //initialLocation = currentLocation
            }
            self.initialLocation = initialLocation
        }
        lastMouseLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        initialLocation = nil
        activeHandle = .none
        dragIng = false
        AppDelegate.shared.isResizing = false
        if let rect = selectionRect {
            SCContext.screenArea = rect
        }
        ease(false)
        pointerMoved(event)
    }
}

class ScreenshotWindow: NSPanel {
    
    init(contentRect: NSRect, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool, size: NSSize, force: Bool = false) {
        let overlayView = ScreenshotOverlayView(frame: contentRect, size:size, force: force)
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: bufferingType, defer: flag)
        self.isOpaque = false
        self.hasShadow = false
        self.level = .statusBar
        self.backgroundColor = NSColor.clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.contentView = overlayView
        
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: myKeyDownEvent)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func myKeyDownEvent(event: NSEvent) -> NSEvent? {
        // Esc closes an open bubble of the capsule first (its own monitor takes it); the next one cancels the selection
        if event.keyCode == 53 && MainActor.assumeIsolated({ CapsuleBubbles.shared.open != nil }) { return event }
        if event.keyCode == 53 && !event.isARepeat {
            self.close()
            for w in NSApp.windows.filter({ $0.title == "Start Recording".local }) { w.close() }
            AppDelegate.shared.stopGlobalMouseMonitor()
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
            return nil
        }
        return event
    }
}

extension ResizeHandle {
    /// Where the handle sits on `r` in flipped coordinates, where the top is minY
    func point(inFlipped r: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: r.minX, y: r.minY)
        case .top: CGPoint(x: r.midX, y: r.minY)
        case .topRight: CGPoint(x: r.maxX, y: r.minY)
        case .right: CGPoint(x: r.maxX, y: r.midY)
        case .bottomRight: CGPoint(x: r.maxX, y: r.maxY)
        case .bottom: CGPoint(x: r.midX, y: r.maxY)
        case .bottomLeft: CGPoint(x: r.minX, y: r.maxY)
        case .left: CGPoint(x: r.minX, y: r.midY)
        case .none: CGPoint(x: r.midX, y: r.midY)
        }
    }
}

enum ResizeHandle: CaseIterable {
    case none
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    
    static var allCases: [ResizeHandle] {
        return [.none, .topLeft, .top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left]
    }
}

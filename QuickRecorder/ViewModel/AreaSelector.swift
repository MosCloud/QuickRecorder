//
//  AreaSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/20.
//

import SwiftUI
import ScreenCaptureKit
import Quartz
import CoreImage

/// The marks' hosting view: the view under the pointer over the overlay, so the cursor rect it carries is the one
/// AppKit keeps. SwiftUI's own arrow rects are replaced by this one (#136)
final class MarksHost<Content: View>: NSHostingView<Content> {
    var cursor: NSCursor = .crosshair

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }
}

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
    /// The camera housing on the overlay's screen, kept clear by the size (#110)
    @Published var notch: CGRect?
}

/// Over the frost (#97): its cut edge catching the light, the corners, a bar on the edge under the pointer, and the size
struct AreaMarks: View {
    @ObservedObject var model: AreaMarksModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { _ in
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
                sizeTag(r)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func sizeTag(_ r: CGRect) -> some View {
        SizeTagSpot(area: r, notch: model.notch) {
            OverlayCapsule {
                Text(verbatim: "\(Int(r.width)) × \(Int(r.height))")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .padding(.horizontal, 10).padding(.vertical, 4)
            }
        }
    }
}

/// Puts the size where `SizeTag` says, measured as it's drawn
private struct SizeTagSpot: Layout {
    let area: CGRect
    let notch: CGRect?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let tag = subviews.first else { return }
        let center = SizeTag.center(area: area, tag: tag.sizeThatFits(.unspecified), screen: bounds.size, notch: notch)
        tag.place(at: CGPoint(x: bounds.minX + center.x, y: bounds.minY + center.y), anchor: .center, proposal: .unspecified)
    }
}

/// The frost around the area (#108): a picture of the screen as the selector opens, blurred as lightly as the prototype
/// the owner chose in #97. The system's materials blur far more, and how much can't be set.
@MainActor
enum AreaFrost {
    /// The prototype's "medium": a 10-point blur under a 16% tint, dark in dark mode and light in light
    static let radius: CGFloat = 10
    static let tint: CGFloat = 0.16
    /// The display without QuickRecorder's own windows, frosted; nil when it can't be captured
    static func picture(of display: SCDisplay) async -> CGImage? {
        guard let screen = display.nsScreen else { return nil }
        let scale = screen.backingScaleFactor
        let own = SCContext.getSelf().map { [$0] } ?? []
        let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(CGFloat(display.width) * scale)
        configuration.height = Int(CGFloat(display.height) * scale)
        configuration.showsCursor = false
        guard let shot = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) else { return nil }
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return frosted(shot, radius: radius * scale, dark: dark)
    }

    private static func frosted(_ image: CGImage, radius: CGFloat, dark: Bool) -> CGImage? {
        let input = CIImage(cgImage: image)
        // Clamped first, so the edges blur against themselves rather than fade to clear
        let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
        let shade: CGFloat = dark ? 0 : 1
        let tinted = CIImage(color: CIColor(red: shade, green: shade, blue: shade, alpha: tint)).cropped(to: input.extent).composited(over: blurred)
        return CIContext().createCGImage(tinted, from: input.extent)
    }
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
        AppDelegate.shared.resizeAreaSelector(to: NSSize(width: areaWidth, height: areaHeight))
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
        ], screen: screen.nsScreen) {
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

    /// The frost with the area cut out of it (#108), and over it the marks (#97)
    private let frost = NSView()
    private let cutOut = CAShapeLayer()
    private let marks = AreaMarksModel()
    private var eased = false
    /// The marks' hosting view, which owns the cursor rect over the overlay (#136)
    private var marksHost: MarksHost<AreaMarks>?
    /// The shape the pointer was last given: a mouse-moved event that finds the same shape doesn't set it again, while
    /// the timer re-asserts it against the window's own rects (#136)
    private var lastCursorKey: String?
    /// The button is down: the pointer keeps the drag's own shape rather than following the area moving under it (#136)
    private var buttonDown = false
    /// The shape the pointer should have; the timer re-asserts it, since AppKit puts its own rects back over ours (#136)
    private var wantedCursor: NSCursor = .crosshair
    /// Refreshes the pointer while the selector is up: after a drag the window stopped sending mouse-moved events, so
    /// the resize cursor set at the end of the drag stayed (#136)
    private var cursorTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        // Hosting its own layer: the picture and the cut-out are set on it directly
        frost.layer = CALayer()
        frost.wantsLayer = true
        frost.layer?.contentsGravity = .resize
        cutOut.fillRule = .evenOdd
        frost.layer?.mask = cutOut
        frost.frame = bounds
        frost.autoresizingMask = [.width, .height]
        // Clear until the picture is ready
        frost.alphaValue = 0
        addSubview(frost)

        // A whisker of black over the whole overlay: the cut-out is otherwise fully transparent, and the window server
        // hands clicks on transparent pixels to whatever is behind the window (#114)
        let clickable = NSView(frame: bounds)
        clickable.wantsLayer = true
        clickable.layer?.backgroundColor = NSColor.black.withAlphaComponent(1.0 / 255.0).cgColor
        clickable.autoresizingMask = [.width, .height]
        addSubview(clickable)
        let host = MarksHost(rootView: AreaMarks(model: marks))
        marksHost = host
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
        // A remembered rectangle comes back inside the whole screen (#156); only a screen's first one keeps clear of
        // the menu bar and the Dock, and `AreaRect.initial(visible:)` decides that
        selectionRect = AreaRect.restored(savedArea, screen: bounds, visible: visibleArea)
        if self.window != nil {
            areaWidth = Int(selectionRect!.width)
            areaHeight = Int(selectionRect!.height)
            SCContext.screenArea = selectionRect
        }
        // The overlay covers its screen, so the screen's notch is where it is on the overlay
        marks.notch = window?.screen?.notch
        startCursorTimer()
    }

    /// The Edit Area bubble changed the size: the rectangle takes it where it sits, keeping its middle, instead of
    /// the overlay being rebuilt for every digit typed (#113, #129)
    func apply(size newSize: NSSize) {
        guard let rect = selectionRect else { return }
        selectionRect = AreaRect.resized(rect, to: newSize, screen: bounds)
        areaWidth = Int(selectionRect!.width)
        areaHeight = Int(selectionRect!.height)
        SCContext.screenArea = selectionRect
    }

    /// Leaving the screen keeps its selection, also when the selection is cancelled: the next visit starts where this
    /// one left off (#113)
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            stopCursorTimer()
            NSCursor.arrow.set()
            // The overlay is going away: bring the menu bar and the Dock back (#163)
            PickerPresentation.end()
        }
        if newWindow == nil, let rect = selectionRect, rect.width > 0, rect.height > 0,
           let name = window?.screen?.localizedName {
            let all = ud.object(forKey: "savedArea") as? [String: [String: CGFloat]] ?? [:]
            ud.set(AreaRect.saving(all, screen: name, rect: rect), forKey: "savedArea")
        }
        super.viewWillMove(toWindow: newWindow)
    }

    /// This screen's visible frame (what the menu bar and the Dock leave) moved into the overlay's coordinates, which
    /// start at the screen's own bottom left (#113)
    private var visibleArea: CGRect {
        guard let screen = window?.screen ?? NSScreen.main else { return bounds }
        return screen.visibleFrame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
    }

    /// The rectangle this screen remembers, if any (#113)
    private var savedArea: CGRect? {
        guard let name = window?.screen?.localizedName,
              let all = ud.object(forKey: "savedArea") as? [String: [String: CGFloat]],
              let area = all[name],
              let x = area["x"], let y = area["y"], let w = area["width"], let h = area["height"] else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    override func layout() {
        super.layout()
        updateCursor()
    }

    // The frost and the marks only show: every click is the overlay's
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }

    /// The capsule takes key when it opens under the overlay, so the overlay's first click would otherwise only
    /// bring it forward and be swallowed: the click that starts a drag has to land (#133)
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Frost everywhere but the area, and the marks around it
    private func layoutMarks() {
        guard let r = selectionRect else { return }
        let b = bounds
        let path = CGMutablePath()
        path.addRect(b)
        path.addRect(r)
        // Following the pointer, not animating after it
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cutOut.frame = b
        cutOut.path = path
        CATransaction.commit()
        marks.rect = CGRect(x: r.minX, y: b.height - r.maxY, width: r.width, height: r.height)
        updateCursor()
    }

    /// Frosts the overlay with `display`'s picture once it's taken
    func frost(_ display: SCDisplay) {
        Task { @MainActor in
            if let picture = await AreaFrost.picture(of: display) {
                frost.layer?.contents = picture
            } else {
                // No picture, as without the screen recording permission: a light shade instead
                frost.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
            }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                frost.animator().alphaValue = eased ? 0.25 : 1
            }, completionHandler: nil)
        }
    }

    /// While the area moves or changes size the frost thins, so what's around it shows to line it up against
    private func ease(_ on: Bool) {
        guard on != eased else { return }
        eased = on
        // Not before the picture is in
        guard frost.layer?.contents != nil || frost.layer?.backgroundColor != nil else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            frost.animator().alphaValue = on ? 0.25 : 1
        }
    }

    /// Where each handle takes the pointer: a square at a corner, the rest of the edge between them
    private func zone(_ handle: ResizeHandle, of r: NSRect) -> NSRect {
        // A small area's corners would otherwise cover all of it, leaving no room to drag it (#136)
        let corner = min(28, max(r.width, r.height) / 3), edge = min(14, min(r.width, r.height) / 3)
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
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { pointerMoved(event) }
    override func mouseEntered(with event: NSEvent) { pointerMoved(event) }
    override func cursorUpdate(with event: NSEvent) { pointerMoved(event) }

    /// The pointer left this screen's overlay: hand it back once instead of leaving our shape on the other screen (#157)
    override func mouseExited(with event: NSEvent) {
        lastCursorKey = nil
        NSCursor.arrow.set()
    }

    private func pointerMoved(_ event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    /// The pointer's shape follows what can be done where it is now, so it is also right when the area changes under a
    /// pointer that hasn't moved: on opening, after the Edit Area bubble, after a drag (#136)
    private func updateCursor(at point: NSPoint? = nil) {
        guard let window, window.isVisible else { return }
        let here = point ?? convert(window.mouseLocationOutsideOfEventStream, from: nil)
        // The overlay covers one screen: with the pointer on another one nothing here owns it, and the app under it
        // keeps its own shape (#157)
        guard bounds.contains(here) else { return }

        // While the button is down the pointer speaks for what the drag does, not for what it has just drawn
        if buttonDown {
            let key = activeHandle != .none ? "\(activeHandle)" : (dragIng ? "closedHand" : "crosshair")
            apply(cursor(for: activeHandle, at: here), key: key, at: here)
            return
        }

        let handle = handleForPoint(here)
        if marks.handle != handle { marks.handle = handle }
        let key = handle == .none
            ? (selectionRect?.contains(here) == true ? (dragIng ? "closedHand" : "openHand") : "crosshair")
            : "\(handle)"
        apply(cursor(for: handle, at: here), key: key, at: here)
    }

    /// Takes the cursor as this view's own (#136). The rect on the marks' host says what it should be, and
    /// `set()` shows it now; the rects are never invalidated from here, because doing that while AppKit is
    /// updating its structural regions (as it is in `mouseMoved`) throws and takes the app down
    private func apply(_ cursor: NSCursor, key: String, at point: NSPoint) {
        wantedCursor = cursor
        marksHost?.cursor = cursor
        guard key != lastCursorKey else { return }
        lastCursorKey = key
        cursor.set()
    }

    private func startCursorTimer() {
        guard cursorTimer == nil else { return }
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let window = self.window, window.isVisible else { return }
                // Only while the pointer is on this screen's overlay (#157): the overlay of another screen, or another
                // app on the other side of it, keeps its own pointer
                let mouse = NSEvent.mouseLocation
                guard window.frame.contains(mouse) else { return }
                // A window of ours above this one (the capsule and its bubbles) keeps the pointer to itself
                guard !NSApp.windows.contains(where: { $0 !== window && $0.isVisible && $0.frame.contains(mouse) }) else { return }
                self.updateCursor()
                // AppKit re-applies the window's own rects as the pointer moves, so say it again while we have it (#136)
                self.wantedCursor.set()
            }
        }
        if let cursorTimer { RunLoop.main.add(cursorTimer, forMode: .common) }
    }

    private func stopCursorTimer() {
        cursorTimer?.invalidate()
        cursorTimer = nil
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
        buttonDown = true
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
                let limit = bounds
                let origin = NSPoint(x: max(limit.origin.x, min(initialLocation.x, currentLocation.x)), y: max(limit.origin.y, min(initialLocation.y, currentLocation.y)))
                var maxH = abs(currentLocation.y - initialLocation.y)
                var maxW = abs(currentLocation.x - initialLocation.x)
                if currentLocation.y < limit.origin.y { maxH = initialLocation.y }
                if currentLocation.x < limit.origin.x { maxW = initialLocation.x }
                let size = NSSize(width: maxW, height: maxH)
                // A click is not a new selection: a stray click in the veiled part used to wipe the area down to a
                // pixel or two, after which every click landed outside it (#131)
                guard size.width >= AreaRect.smallestUsable.width,
                      size.height >= AreaRect.smallestUsable.height else { return }
                self.selectionRect = NSIntersectionRect(limit, NSRect(origin: origin, size: size))
                areaWidth = Int(selectionRect!.width)
                areaHeight = Int(selectionRect!.height)
                //initialLocation = currentLocation
            }
            self.initialLocation = initialLocation
        }
        lastMouseLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        buttonDown = false
        initialLocation = nil
        activeHandle = .none
        dragIng = false
        AppDelegate.shared.isResizing = false
        if let rect = selectionRect {
            SCContext.screenArea = rect
        }
        ease(false)
        updateCursor(at: convert(event.locationInWindow, from: nil))
        DispatchQueue.main.async { [weak self] in self?.updateCursor() }
    }
}

class ScreenshotWindow: NSPanel {
    
    init(contentRect: NSRect, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        let overlayView = ScreenshotOverlayView(frame: contentRect)
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: bufferingType, defer: flag)
        self.isOpaque = false
        self.hasShadow = false
        // Owns every click while it is up, the menu bar included (#163)
        self.level = PickerShield.cover
        self.backgroundColor = NSColor.clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.contentView = overlayView
        // Off by default: the pointer's shape would then only change when the tracking area speaks up, so the corner
        // cursor set at the end of a drag stayed put (#136)
        self.acceptsMouseMovedEvents = true
        
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: myKeyDownEvent)
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A borderless panel can't take key unless it says so, and the selector needs the keys: Esc closes it (#131)
    override var canBecomeKey: Bool { true }

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

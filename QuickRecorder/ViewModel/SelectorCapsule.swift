//
//  SelectorCapsule.swift
//  QuickRecorder
//
//  The capsule under every selector (#79): the selector's own buttons, then the cursor, sound, microphone and timer,
//  then Options and Record, with the bubbles they open. It follows the main panel: its material, its microphone's toggle,
//  its icon buttons. Nothing in it shows hover help: the owner keeps it minimal; names go to accessibility only.
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Bubbles

/// What the capsule opens above itself, one at a time. Each is drawn in the capsule's own window, in the panel material:
/// a popover or a menu is a window of its own, which takes key from the capsule's (whose Liquid Glass then flickers to
/// its inactive look) and is always Liquid Glass whatever the material.
enum CapsuleBubble: Hashable { case leading(String), mic, timer, options }

@MainActor
final class CapsuleBubbles: ObservableObject {
    static let shared = CapsuleBubbles()
    @Published private(set) var open: CapsuleBubble?
    /// The open bubble and the controls that open bubbles, each registered by the view itself. A click is measured
    /// against them as they are when it comes: a frame noted earlier went stale, caught mid scale-in at 85% (#105)
    fileprivate weak var bubbleView: NSView?
    fileprivate var sourceViews: [CapsuleBubble: WeakView] = [:]
    /// A surface of the open bubble that lives in a window of its own: the background colour window (#117)
    private var extraHitAreas: [WeakView] = []
    private var monitors: [Any] = []

    /// Surfaces of the open bubble kept where they are: the colour window and the system panel it opens (#117)
    func addHitArea(_ view: NSView) {
        extraHitAreas.removeAll { $0.view == nil || $0.view === view }
        extraHitAreas.append(WeakView(view: view))
    }

    func removeHitArea(_ view: NSView) {
        extraHitAreas.removeAll { $0.view === nil || $0.view === view }
    }

    func toggle(_ bubble: CapsuleBubble) { set(open == bubble ? nil : bubble) }

    func close() {
        guard open != nil else { return }
        // A number typed without Return is kept: ending the edit commits it before its field goes
        NSApp.keyWindow?.makeFirstResponder(nil)
        set(nil)
    }

    private func set(_ bubble: CapsuleBubble?) {
        startDismissal()
        // The colour window is part of the bubble that opened it: it goes when the bubble does
        if bubble == nil { ColorWindow.shared.close() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { open = bubble }
    }

    /// Closes the open bubble on any click outside it, in QuickRecorder's windows or in other apps, on leaving the app,
    /// and on Esc wherever the focus is (before the area selector's own Esc). The click still does what it does,
    /// except on the control that opened the bubble, which only closes it (its own action sees the bubble open).
    private func startDismissal() {
        guard monitors.isEmpty else { return }
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
            let window = event.window, point = event.locationInWindow
            MainActor.assumeIsolated {
                let bubbles = CapsuleBubbles.shared
                guard let open = bubbles.open else { return }
                // The system colour panel is part of the bubble's surface, its title bar and close button too:
                // closing the panel must leave the bubble and the colour window as they are
                if let window, window is NSColorPanel { return }
                if bubbles.bubbleView?.covers(point, in: window) == true { return }
                if bubbles.extraHitAreas.contains(where: { $0.view?.covers(point, in: window) == true }) { return }
                if bubbles.sourceViews[open]?.view?.covers(point, in: window) == true { return }
                bubbles.close()
            }
            return event
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { CapsuleBubbles.shared.close() } }
        } as Any)
        monitors.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { CapsuleBubbles.shared.close() }
        })
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isEscape = event.keyCode == 53
            let closed = MainActor.assumeIsolated {
                guard isEscape else { return false }
                // The colour window is a layer finer than the bubble: Esc closes it before the bubble
                if ColorWindow.shared.isOpen { ColorWindow.shared.close(); return true }
                guard CapsuleBubbles.shared.open != nil else { return false }
                CapsuleBubbles.shared.close()
                return true
            }
            return closed ? nil : event
        } as Any)
    }
}

fileprivate struct WeakView { weak var view: NSView? }

private extension NSView {
    /// Whether a click at `point`, in `window`'s coordinates, lands on this view where it is now
    func covers(_ point: NSPoint, in window: NSWindow?) -> Bool {
        guard let window, self.window === window else { return false }
        return convert(bounds, to: nil).contains(point)
    }
}

/// Marks where a click counts as on the open bubble, or on a control that opens one: the view behind it registers
/// itself, and the click is measured against it then (#105)
private struct HitArea: NSViewRepresentable {
    let source: CapsuleBubble?
    func makeNSView(context: Context) -> Marker { Marker(source: source) }
    func updateNSView(_ view: Marker, context: Context) {}

    final class Marker: NSView {
        let source: CapsuleBubble?
        init(source: CapsuleBubble?) { self.source = source; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            guard window != nil else { return }
            MainActor.assumeIsolated {
                if let source { CapsuleBubbles.shared.sourceViews[source] = WeakView(view: self) } else { CapsuleBubbles.shared.bubbleView = self }
            }
        }
    }
}

/// Catches a right-click (or a Control-click) over a SwiftUI control and lets every other click through to it
private struct RightClick: NSViewRepresentable {
    let action: () -> Void
    func makeNSView(context: Context) -> Catcher { Catcher(action: action) }
    func updateNSView(_ view: Catcher, context: Context) { view.action = action }

    final class Catcher: NSView {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        private var isSecondaryClick: Bool {
            guard let event = NSApp.currentEvent else { return false }
            return event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        }
        override func hitTest(_ point: NSPoint) -> NSView? { isSecondaryClick ? super.hitTest(point) : nil }
        override func rightMouseDown(with event: NSEvent) { action() }
        override func mouseDown(with event: NSEvent) { action() }
    }
}

private let bubbleTransition = AnyTransition.asymmetric(
    insertion: .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity),
    removal: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity))

/// Shows a bubble above a 30-point control while it's open: its bottom 8 points over the capsule's top. Centred on the
/// control, or from its left edge for the selector's own buttons, which sit too near the capsule's start to centre on.
private struct BubbleAnchor<Bubble: View>: ViewModifier {
    @ObservedObject var bubbles = CapsuleBubbles.shared
    let which: CapsuleBubble
    let alignment: Alignment
    let bubble: Bubble
    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            if bubbles.open == which { bubble.offset(y: -46).transition(bubbleTransition) }
        }
    }
}

private extension View {
    func bubble<B: View>(_ which: CapsuleBubble, alignment: Alignment = .bottom, @ViewBuilder _ bubble: () -> B) -> some View {
        modifier(BubbleAnchor(which: which, alignment: alignment, bubble: bubble()))
    }

    /// The panel material's colour scheme: black is always dark
    func capsuleScheme(_ material: PanelMaterial, _ scheme: ColorScheme) -> some View {
        environment(\.colorScheme, material == .black ? .dark : scheme)
    }
}

/// The main panel's three materials
struct CapsuleMaterial<S: Shape>: View {
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    let shape: S
    var body: some View {
        switch material {
        case .glass: Color.clear.glassEffect(.regular, in: shape)
        case .blur: shape.fill(.regularMaterial).environment(\.controlActiveState, .active)
        case .black: shape.fill(.black)
        }
    }
}

/// A bubble's look: the capsule's material and colour scheme, a shadow off glass
private struct BubbleChrome<Content: View>: View {
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    @Environment(\.colorScheme) private var colorScheme
    var corner: CGFloat = 14
    var horizontal: CGFloat = 12
    var vertical: CGFloat = 10
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, horizontal).padding(.vertical, vertical)
            .background(CapsuleMaterial(shape: RoundedRectangle(cornerRadius: corner, style: .continuous)))
            .background(HitArea(source: nil))
            .shadow(color: .black.opacity(material == .glass ? 0 : 0.25), radius: 8, y: 2)
            .capsuleScheme(material, colorScheme)
            .fixedSize()
    }
}

// MARK: - The capsule

/// A button of the selector's own, at the capsule's start: Refresh, Close, the area's Window Area and Resize
struct CapsuleLeading: Identifiable {
    let symbol: String
    let label: String
    /// Refresh turns when pressed
    var spins = false
    var action: (() -> Void)?
    /// Its own settings: a click opens them when it has no action, a right-click when it has one
    var bubble: AnyView?
    var id: String { symbol }
}

struct SelectorCapsule: View {
    var leading: [CapsuleLeading]
    /// The display being recorded: its refresh rate bounds the frame rates, its scale whether Retina differs
    var screen: NSScreen?
    /// Screen and area recordings show the screen as it is (#83)
    var showsBackground = true
    /// System audio has no picture (#96): no cursor, no Options, and its own audio is what it records
    var recordsVideo = true
    var canStart = true
    /// Starts with the seconds after which to stop, 0 for never
    let start: (_ autoStop: TimeInterval) -> Void

    @AppStorage("showMouse")        private var showMouse = true
    @AppStorage("recordWinSound")   private var recordWinSound = true
    @AppStorage("recordMic")        private var recordMic = false
    @AppStorage("micDevice")        private var micDevice = "default"
    @AppStorage("autoStopOn")       private var autoStopOn = false
    @AppStorage("autoStopDuration") private var autoStopDuration = 0
    @AppStorage("capsuleMaterial")  private var material: PanelMaterial = .glass
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var bubbles = CapsuleBubbles.shared
    @State private var micList = SCContext.getMicrophone()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(leading) { LeadingButton(item: $0) }
            separator
            if recordsVideo {
                CapsuleToggle(on: "cursorarrow", off: "cursorarrow.slash", tint: .blue, label: "Record Cursor".local, isOn: $showMouse)
                CapsuleToggle(on: "speaker.wave.2.fill", off: "speaker.slash", tint: .orange, label: "App's Audio".local, isOn: $recordWinSound)
            }
            // Click to switch on or off, right-click for its own settings: the microphone's device, the timer's duration
            CapsuleToggle(on: "mic.fill", off: "mic.slash", tint: .green, label: "Microphone".local, isOn: $recordMic, owns: .mic)
                .disabled(micList.isEmpty)
                .overlay(RightClick { bubbles.toggle(.mic) })
                .bubble(.mic) { MicBubble(devices: micList.map(\.localizedName)) }
            CapsuleTimer()
            separator
            if recordsVideo {
                CapsuleIcon(symbol: "slider.horizontal.3", label: "Options".local, active: bubbles.open == .options) { bubbles.toggle(.options) }
                    .background(HitArea(source: .options))
            }
            Button {
                bubbles.close()
                start(autoStopOn ? TimeInterval(autoStopDuration) : 0)
            } label: {
                Label("Record", systemImage: "record.circle.fill")
            }
            .buttonStyle(RecordButtonStyle())
            .disabled(!canStart)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(CapsuleMaterial(shape: Capsule()))
        .capsuleScheme(material, colorScheme)
        // Options is wide: it lines up with the capsule's right end rather than its button
        .overlay(alignment: .bottomTrailing) {
            if bubbles.open == .options {
                OptionsBubble(screen: screen, showsBackground: showsBackground).offset(y: -54).transition(bubbleTransition)
            }
        }
        .fixedSize()
        .onChange(of: recordMic) { Task { await SCContext.performMicCheck() } }
        .onAppear {
            if micList.isEmpty { recordMic = false }
            if !micList.map(\.localizedName).contains(micDevice) { micDevice = "default" }
        }
        .onDisappear { bubbles.close() }
    }

    private var separator: some View { Divider().frame(height: 20).padding(.horizontal, 4) }
}

private struct LeadingButton: View {
    let item: CapsuleLeading
    @ObservedObject private var bubbles = CapsuleBubbles.shared
    var body: some View {
        let which = CapsuleBubble.leading(item.symbol)
        let opensOnClick = item.action == nil && item.bubble != nil
        CapsuleIcon(symbol: item.symbol, label: item.label, spins: item.spins, active: bubbles.open == which) {
            if let action = item.action {
                if bubbles.open == which { bubbles.close() } else { action() }
            } else if item.bubble != nil {
                bubbles.toggle(which)
            }
        }
        .background { if item.bubble != nil { HitArea(source: which) } }
        .overlay { if item.bubble != nil && !opensOnClick { RightClick { bubbles.toggle(which) } } }
        .bubble(which, alignment: .bottomLeading) { if let bubble = item.bubble { BubbleChrome(horizontal: 6, vertical: 6) { bubble } } }
    }
}

/// A toggle drawn like the main panel's microphone (#48): filled in its own colour when on, a grey slash when off,
/// swapping with the symbol's own transition and bouncing when turned on; a round highlight under the pointer
private struct CapsuleToggle: View {
    let on: String
    let off: String
    /// Each toggle has its own: the microphone keeps the main panel's green
    let tint: Color
    let label: String
    @Binding var isOn: Bool
    /// The bubble a right-click opens: while it's open, a click only closes it
    var owns: CapsuleBubble?
    @ObservedObject private var bubbles = CapsuleBubbles.shared
    @State private var hovering = false
    @State private var bounces = 0
    /// 1.5× the system speed, as the main panel's microphone
    private let speed = 1.5

    var body: some View {
        Button {
            if let owns, bubbles.open == owns { bubbles.close(); return }
            isOn.toggle()
            if isOn { bounces += 1 }
        } label: {
            Image(systemName: isOn ? on : off)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace, options: .speed(speed)))
                .symbolEffect(.bounce, options: .speed(speed), value: bounces)
                .frame(width: 32, height: 30)
                .background(.primary.opacity(hovering || (owns != nil && bubbles.open == owns) ? 0.12 : 0.0001), in: Circle())
                .animation(.smooth(duration: 0.2 / speed), value: isOn)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .background { if let owns { HitArea(source: owns) } }
    }
}

/// The timer, a toggle like the others: red while on, a grey slash while off. A click switches it, keeping its duration
/// while off and taking ten minutes when it has none; a right-click opens the duration (which doesn't switch it).
private struct CapsuleTimer: View {
    @AppStorage("autoStopOn")       private var autoStopOn = false
    @AppStorage("autoStopDuration") private var autoStopDuration = 0
    @ObservedObject private var bubbles = CapsuleBubbles.shared
    @State private var hovering = false
    @State private var bounces = 0
    private let speed = 1.5

    var body: some View {
        Button {
            if bubbles.open == .timer { bubbles.close(); return }
            let next = AutoStop.toggled(on: autoStopOn, duration: AutoStop(totalSeconds: autoStopDuration))
            autoStopDuration = next.duration.totalSeconds
            autoStopOn = next.on
        } label: {
            Image(systemName: autoStopOn ? "alarm" : "alarm.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(autoStopOn ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace, options: .speed(speed)))
                .symbolEffect(.bounce, options: .speed(speed), value: bounces)
                .frame(width: 32, height: 30)
                .background(.primary.opacity(hovering || bubbles.open == .timer ? 0.12 : 0.0001), in: Circle())
                .animation(.smooth(duration: 0.2 / speed), value: autoStopOn)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Auto Stop".local)
        .accessibilityAddTraits(autoStopOn ? .isSelected : [])
        .onChange(of: autoStopOn) { _, on in if on { bounces += 1 } }
        .background(HitArea(source: .timer))
        .overlay(RightClick { bubbles.toggle(.timer) })
        .bubble(.timer) { BubbleChrome(corner: 19, vertical: 8) { TimerFields() } }
    }
}

/// An icon button like the main panel's: grey until hovered (or while its bubble is open), then brighter on a round highlight
private struct CapsuleIcon: View {
    let symbol: String
    let label: String
    var spins = false
    var active = false
    let action: () -> Void
    @State private var hovering = false
    @State private var turns = 0

    var body: some View {
        Button {
            if spins { turns += 1 }
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: 15))
                .symbolEffect(.rotate.clockwise, options: .speed(1.5), value: turns)
                .foregroundStyle(hovering || active ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(width: 32, height: 30)
                .background(.primary.opacity(hovering || active ? 0.12 : 0.0001), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
    }
}

/// Red, white text, whether or not the window is active (the system's prominent styles grey out in inactive windows)
private struct RecordButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 14).frame(height: 30)
            .background(Capsule().fill(Color.red.opacity(configuration.isPressed ? 0.75 : 1)))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Capsule())
    }
}

// MARK: - What the bubbles hold

/// A two-digit number in a soft rounded field. A number past its range goes back to 0 (#87).
private struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var digits = 2
    var width: CGFloat = 28
    /// Bumped to redraw a field set back to 0 that was 0 already
    @State private var version = 0

    var body: some View {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimumIntegerDigits = digits
        let checked = Binding(get: { value }, set: {
            value = range.orZero($0)
            if value != $0 { version += 1 }
        })
        return TextField("", value: checked, formatter: formatter)
            .onSubmit { CapsuleBubbles.shared.close() }
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(width: width, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.quaternary))
            .id(version)
    }
}

/// The timer's duration: two-digit hours, minutes and seconds, then Reset as text. Reset is text like Settings'
/// Restore Defaults, so the circling arrow only ever means Refresh. Editing doesn't switch the timer; clearing it does.
private struct TimerFields: View {
    @AppStorage("autoStopOn")       private var autoStopOn = false
    @AppStorage("autoStopDuration") private var autoStopDuration = 0

    var body: some View {
        HStack(spacing: 4) {
            NumberField(value: part(\.hours), range: AutoStop.hourRange); unit("hr")
            NumberField(value: part(\.minutes), range: AutoStop.minuteRange); unit("min")
            NumberField(value: part(\.seconds), range: AutoStop.secondRange); unit("sec")
            Button("Reset") { set(AutoStop()) }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .disabled(autoStopDuration == 0)
                .padding(.leading, 6)
        }
        .fixedSize()
    }

    private func part(_ key: WritableKeyPath<AutoStop, Int>) -> Binding<Int> {
        Binding(get: { AutoStop(totalSeconds: autoStopDuration)[keyPath: key] }, set: {
            var duration = AutoStop(totalSeconds: autoStopDuration)
            duration[keyPath: key] = $0
            set(duration)
        })
    }

    private func set(_ duration: AutoStop) {
        autoStopDuration = duration.totalSeconds
        autoStopOn = AutoStop.staysOn(autoStopOn, after: duration)
    }

    private func unit(_ key: String) -> some View {
        Text(key.local).font(.system(size: 12)).foregroundStyle(.secondary)
    }
}

/// The microphones, a tick on the chosen one; choosing one closes it
private struct MicBubble: View {
    let devices: [String]
    @AppStorage("micDevice") private var micDevice = "default"

    var body: some View {
        BubbleChrome(horizontal: 6, vertical: 6) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(["default"] + devices, id: \.self) { device in
                    BubbleRow(title: device == "default" ? "Default".local : device, checked: micDevice == device) {
                        micDevice = device
                        CapsuleBubbles.shared.close()
                    }
                }
            }
            .frame(width: 210)
        }
    }
}

/// A row of a bubble's list: a tick when chosen, a soft highlight under the pointer
struct BubbleRow: View {
    let title: String
    let checked: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)).opacity(checked ? 1 : 0)
                Text(title).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.primary.opacity(hovering ? 0.1 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Resolution, frame rate, quality, background (window and app recordings) and HDR, in the capsule's own controls
private struct OptionsBubble: View {
    let screen: NSScreen?
    let showsBackground: Bool
    @AppStorage("highRes")      private var highRes = 2
    @AppStorage("frameRate")    private var frameRate = 60
    @AppStorage("videoQuality") private var videoQuality = 1.0
    @AppStorage("background")   private var background: BackgroundType = .wallpaper
    @AppStorage("recordHDR")    private var recordHDR = false
    @ObservedObject private var colors = ColorWindow.shared.model

    var body: some View {
        let retina = (screen?.backingScaleFactor ?? 2) > 1
        BubbleChrome(horizontal: 14, vertical: 12) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    label("Resolution")
                    // On a 1x display both record alike: Standard shows, the setting stays for a Retina display
                    Segments(items: [(2, "Retina"), (1, "Standard".local)], value: Binding(get: { retina ? highRes : 1 }, set: { highRes = $0 }))
                        .disabled(!retina)
                }
                GridRow {
                    label("Frame Rate")
                    FrameRateStepper(value: $frameRate, maxFPS: screen?.maximumFramesPerSecond ?? 60)
                }
                GridRow {
                    label("Picture Quality")
                    Segments(items: [(1.0, "High ".local), (0.7, "Medium ".local), (0.3, "Low ".local)], value: $videoQuality)
                }
                if showsBackground {
                    // Custom opens the colour window beside the bubble, which stays open while it is used (#117)
                    GridRow { label("Background"); Swatches(value: $background, customColor: colors.color) }
                }
                GridRow {
                    label("HDR")
                    Toggle("", isOn: $recordHDR).toggleStyle(.switch).controlSize(.mini).labelsHidden()
                }
            }
        }
        // A click on the bubble's blank space puts the colour window away, leaving the bubble open; the controls
        // above it take their own clicks first
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { ColorWindow.shared.close() }
        .background(BubbleFrameReporter())
    }

    private func label(_ key: String) -> some View {
        Text(key.local).font(.system(size: 12)).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
    }
}

/// A segmented choice in the capsule's style: the chosen one on a pill that slides between them
private struct Segments<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var value: T
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                let (tag, title) = items[i]
                Button { withAnimation(.smooth(duration: 0.2)) { value = tag } } label: {
                    Text(title).font(.system(size: 12))
                        .foregroundStyle(value == tag ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, 9).frame(height: 22)
                        .background {
                            if value == tag { Capsule().fill(.primary.opacity(0.16)).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(.primary.opacity(0.06)))
    }
}

/// The frame rate stepped with arrows on either side, ‹ 60 FPS ›, through the rates the display can show. A setting
/// above them reads as the display's top rate and stays for a faster display.
private struct FrameRateStepper: View {
    @Binding var value: Int
    let maxFPS: Int

    var body: some View {
        let shown = FrameRates.effective(value, maxFPS: maxFPS)
        let rates = Array(Set(FrameRates.available(maxFPS: maxFPS) + [shown])).sorted()
        let i = rates.firstIndex(of: shown) ?? 0
        HStack(spacing: 0) {
            step("chevron.left", enabled: i > 0) { value = rates[i - 1] }
            Text("\(shown) FPS").font(.system(size: 12).monospacedDigit()).frame(width: 64)
                .contentTransition(.numericText(value: Double(shown)))
            step("chevron.right", enabled: i < rates.count - 1) { value = rates[i + 1] }
        }
        .padding(2)
        .background(Capsule().fill(.primary.opacity(0.06)))
    }

    private func step(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.smooth(duration: 0.2)) { action() } } label: {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.secondary).disabled(!enabled).opacity(enabled ? 1 : 0.35)
    }
}

/// The backgrounds as swatches, the chosen one ringed like a chosen thumbnail. Custom is the colour picked in the
/// window it opens (#117); the presets are the ones a recording asks for, the rest of the palette lives in that window.
private struct Swatches: View {
    @Binding var value: BackgroundType
    let customColor: Color
    @AppStorage("withAlpha") private var withAlpha = false

    var body: some View {
        let types: [BackgroundType] = [.wallpaper] + (withAlpha ? [.clear] : []) + [.black, .white, .gray, .blue, .green, .custom]
        HStack(spacing: 2) {
            ForEach(types, id: \.self) { type in
                Button {
                    withAnimation(.smooth(duration: 0.2)) { value = type }
                    // The window belongs to Custom: it opens with it and closes when another background is picked
                    if type == .custom { ColorWindow.shared.show() } else { ColorWindow.shared.close() }
                } label: {
                    swatch(type).frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.25), lineWidth: 0.5))
                        .padding(3)
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: value == type ? 2 : 0))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                // The names the Background menu had: "Wallpaper", "Transparent", "Black" and so on
                .accessibilityLabel((type == .clear ? "Transparent" : type.rawValue.capitalized).local)
            }
        }
    }

    @ViewBuilder private func swatch(_ type: BackgroundType) -> some View {
        switch type {
        case .wallpaper:
            Circle().fill(LinearGradient(colors: [.blue, .purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Image(systemName: "photo").font(.system(size: 7, weight: .semibold)).foregroundStyle(.white))
        case .clear:
            Circle().fill(.background).overlay(Image(systemName: "checkerboard.rectangle").font(.system(size: 8)).foregroundStyle(.secondary))
        case .custom:
            // The colour chosen, in a ring of every colour
            Circle().fill(customColor)
                .overlay(Circle().strokeBorder(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center), lineWidth: 3.5))
        default:
            Circle().fill(Color(cgColor: SCContext.color(for: type)))
        }
    }
}

/// Reports where the bubble is on screen, in AppKit's bottom-left coordinates, so the colour window can sit beside it
private struct BubbleFrameReporter: NSViewRepresentable {
    func makeNSView(context: Context) -> Reporter { Reporter() }
    func updateNSView(_ view: Reporter, context: Context) {}

    final class Reporter: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); report() }
        override func layout() { super.layout(); report() }

        private func report() {
            guard window != nil else { return }
            MainActor.assumeIsolated {
                ColorWindow.shared.note(view: self)
                CapsuleBubbles.shared.addHitArea(self)
            }
        }
    }
}

// MARK: - Floating capsule

/// The capsule on its own, over the screen: the area selector's and the clicked window's (#79). It keeps key, so its
/// Liquid Glass keeps its active look; stays up while QuickRecorder isn't frontmost; and leaves clear room around the
/// capsule for the glass's rim, growing upward while a bubble is open so the capsule itself never moves.
final class FloatingCapsulePanel: NSPanel {
    var onCancel: (() -> Void)?
    private var opened: Any?
    private var base = NSSize.zero
    /// Room above the capsule for the tallest bubble
    private let headroom: CGFloat = 300
    /// Room on each side, for a bubble wider than a short capsule under it: the System Audio one's microphone (#100)
    private let sideRoom: CGFloat = 150

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }

    @MainActor
    /// `within` keeps the capsule on screen, for a clicked window near its edge
    static func show<Content: View>(_ content: Content, title: String, centerX: CGFloat, bottom: CGFloat, within: NSRect? = nil,
                                    level: NSWindow.Level = .screenSaver) -> FloatingCapsulePanel {
        let host = NSHostingView(rootView: FloatingRoot(content: content))
        let panel = FloatingCapsulePanel(contentRect: .zero, styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
                                         backing: .buffered, defer: false)
        panel.title = title
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The window shadow outlines a borderless window in a dark line, which shows as a black rim around Liquid Glass
        panel.hasShadow = ud.string(forKey: "capsuleMaterial") != PanelMaterial.glass.rawValue
        panel.level = level
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.base = host.fittingSize
        var x = centerX - panel.base.width / 2
        if let within { x = min(max(x, within.minX), within.maxX - panel.base.width) }
        panel.setFrame(NSRect(x: x, y: bottom, width: panel.base.width, height: panel.base.height), display: true)
        // Glass in a window that isn't key draws a dark rim, as the main panel never does: it's key
        panel.makeKeyAndOrderFront(nil)
        panel.opened = CapsuleBubbles.shared.$open.sink { [weak panel] open in
            DispatchQueue.main.async { panel?.fit(bubbleOpen: open != nil) }
        }
        return panel
    }

    @MainActor
    private func fit(bubbleOpen: Bool) {
        if bubbleOpen {
            setFrame(fitted(bubbleOpen: true), display: true)
        } else {
            // After the bubble's closing animation, if none opened meanwhile
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, CapsuleBubbles.shared.open == nil else { return }
                setFrame(fitted(bubbleOpen: false), display: true)
            }
        }
    }

    /// Grown the same on both sides, so the capsule centred in it stays put; no wider than the screen allows either side
    private func fitted(bubbleOpen: Bool) -> NSRect {
        var side: CGFloat = 0
        if bubbleOpen {
            let visible = screen?.visibleFrame ?? frame
            let left = frame.midX - base.width / 2 - visible.minX, right = visible.maxX - frame.midX - base.width / 2
            side = max(0, min(sideRoom, left, right))
        }
        let width = base.width + 2 * side
        return NSRect(x: frame.midX - width / 2, y: frame.minY, width: width, height: base.height + (bubbleOpen ? headroom : 0))
    }
}

/// The capsule at the bottom of its panel, clear room around it, taking key when the pointer comes to it
private struct FloatingRoot<Content: View>: View {
    let content: Content
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            content.padding(10)
        }
        // Wide as the panel grows for a bubble, or the hosting view caps the panel at the capsule's width (#100)
        .frame(maxWidth: .infinity)
        .onHover { inside in
            if inside { NSApp.windows.first { $0 is FloatingCapsulePanel && $0.isVisible }?.makeKey() }
        }
    }
}

// MARK: - Thumbnails

/// A thumbnail and its name: the main panel tiles' soft highlight under the pointer, and when chosen an accent ring
/// around the thumbnail with a tick at its corner (#79)
struct SelectableCard<Thumbnail: View>: View {
    let title: String
    /// The thumbnail's width, so a long name is cut short rather than widening the card
    var titleWidth: CGFloat?
    let chosen: Bool
    let action: () -> Void
    @ViewBuilder let thumbnail: Thumbnail
    @State private var hovering = false

    var body: some View {
        Button { withAnimation(.smooth(duration: 0.2)) { action() } } label: {
            VStack(spacing: 6) {
                thumbnail
                    // Behind the thumbnail, so a window's app icon over its bottom edge stays on top of the ring (#94)
                    .background {
                        if chosen {
                            RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 3).padding(-4)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if chosen {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.accentColor))
                                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                                .offset(x: 10, y: -10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(title).font(.system(size: 12))
                    .foregroundStyle(chosen ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(1).truncationMode(.tail)
                    .frame(width: titleWidth)
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(hovering && !chosen ? 0.1 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
    }
}


//
//  NotchCapsule.swift
//  QuickRecorder
//
//  The floating recording controls: a capsule that emerges from the notch when recording starts
//  and retracts into it when recording stops.
//

import SwiftUI

@MainActor
final class CapsuleModel: ObservableObject {
    @Published var layout = CapsuleLayout(windowFrame: .zero, collapsed: .zero, expanded: .zero)
    @Published var expanded = false
    @Published var contentVisible = false
    /// Only animated when Reduce Motion replaces the emerge and retract with a fade.
    @Published var opacity = 1.0
    @Published var kind = RecordingKind.video
    @Published var countdown: Int?
    @Published var elapsed = "00:00"
    @Published var isPaused = false
}

struct NotchCapsuleView: View {
    @ObservedObject var model: CapsuleModel
    @AppStorage("capsuleMaterial") private var material: CapsuleMaterial = .glass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let layout = model.layout
        let rect = model.expanded ? layout.expanded : layout.collapsed
        // Notch-like continuous corners; a hairline start (no notch) stays a hairline
        let shape = RoundedRectangle(cornerRadius: min(10, rect.height / 2), style: .continuous)
        let startsInNotch = layout.collapsed.height > 1
        let isBlack = material == .black
        withMaterial(
            content
                .frame(height: layout.expanded.height)
                .opacity(model.contentVisible ? 1 : 0)
                .blur(radius: model.contentVisible ? 0 : 4)
                .environment(\.colorScheme, isBlack ? .dark : colorScheme)
                .frame(width: rect.width, height: rect.height)
                // Starts as a black block hidden in the notch, which fades into the material on the way down
                .background(shape.fill(.black).opacity(isBlack || model.expanded || !startsInNotch ? 0 : 1))
                .clipShape(shape),
            shape: shape
        )
        .position(x: rect.midX, y: rect.midY)
        .frame(width: layout.windowFrame.width, height: layout.windowFrame.height)
        .opacity(model.opacity)
    }

    @ViewBuilder
    private func withMaterial<V: View, S: Shape>(_ view: V, shape: S) -> some View {
        switch material {
        // Glass only behind the controls: inside it, its vibrancy would wash out the red stop button
        case .glass: view.background { Color.clear.glassEffect(.regular, in: shape) }
        case .blur: view.background(.regularMaterial, in: shape)
        case .black: view.background(Color.black, in: shape)
        }
    }

    @ViewBuilder private var content: some View {
        if let seconds = model.countdown {
            HStack(spacing: 8) {
                Text("\(seconds)")
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                Text("seconds until recording").font(.callout).foregroundStyle(.secondary)
                Button { RecordingControls.shared.capsule.cancelCountdown() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
        } else {
            HStack(spacing: 10) {
                StopButton()
                if model.kind != .device {
                    controlButton(model.isPaused ? "play.fill" : "pause.fill", help: model.isPaused ? "Resume Recording" : "Pause Recording") {
                        RecordingControls.shared.togglePause()
                    }
                }
                Text(model.elapsed)
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(model.isPaused ? .secondary : .primary)
                    .frame(minWidth: 52)
                switch model.kind {
                case .video:
                    Divider().frame(height: 18)
                    controlButton("camera.fill", help: "Camera…") { RecordingControls.shared.capsule.showCamera() }
                case .device:
                    Divider().frame(height: 18)
                    controlButton("apps.ipad", help: "Show iDevice Window") { RecordingControls.shared.toggleDeviceWindow() }
                case .audio:
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func controlButton(_ symbol: String, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .help(help)
    }
}

/// A red rounded square in a ring, like the stop button of QuickTime's and iPhone's screen recording.
private struct StopButton: View {
    @State private var hovering = false

    var body: some View {
        Button { RecordingControls.shared.stop() } label: {
            ZStack {
                Circle().strokeBorder(.primary.opacity(hovering ? 0.9 : 0.55), lineWidth: 2)
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: hovering ? 13 : 12, height: hovering ? 13 : 12)
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
            .animation(.smooth(duration: 0.15), value: hovering)
        }
        .onHover { hovering = $0 }
        .help("Stop Recording")
    }
}

/// Owns the capsule's window. The window is created once, at launch, so it already exists in the window list
/// when a recording's content filter is built, and can be left out of every recording.
@MainActor
final class NotchCapsule {
    private static let size = CGSize(width: 236, height: 40)
    private static let emergeDuration = 0.5

    private let model = CapsuleModel()
    private let panel = CapsulePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var generation = 0
    private var dimming = CapsuleDimming(emergedAt: 0)
    private var hoverTimer: Timer?
    private var countdownTimer: Timer?
    private var onCountdownEnd: (() -> Void)?
    private var isHovering = false
    /// alphaValue is mid-way during a fade, so the value it's heading to is kept separately.
    private var targetAlpha: CGFloat = 1
    private(set) var isShown = false

    var windowID: CGWindowID { CGWindowID(panel.windowNumber) }

    init() {
        let hosting = FirstMouseHostingView(rootView: NotchCapsuleView(model: model))
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Above the menu bar, so it can start out inside the notch
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
    }

    /// Shows the controls for a recording, emerging from the notch unless the capsule is already out (after the countdown).
    func show(kind: RecordingKind) {
        if isShown {
            if model.kind != kind || model.countdown != nil {
                withAnimation(.smooth) {
                    model.kind = kind
                    model.countdown = nil
                }
            }
            return
        }
        emerge(kind: kind, countdown: nil)
    }

    /// Counts down inside the capsule, then calls `action` to start recording.
    func runCountdown(seconds: Int, then action: @escaping () -> Void) {
        emerge(kind: .video, countdown: seconds)
        onCountdownEnd = action
        let gen = generation
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, gen == self.generation, let n = self.model.countdown else { timer.invalidate(); return }
                if n > 1 {
                    withAnimation(.smooth) { self.model.countdown = n - 1 }
                    return
                }
                timer.invalidate()
                self.countdownTimer = nil
                self.dimming.activity(at: Self.now)
                let action = self.onCountdownEnd
                self.onCountdownEnd = nil
                action?()
                // If recording didn't start after all (say the output folder is missing), put the capsule away
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { RecordingControls.shared.sync() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    func cancelCountdown() {
        onCountdownEnd = nil
        retract()
        for w in NSApp.windows where w.title == "Area Overlayer".local { w.close() }
    }

    func update(elapsed: String, paused: Bool) {
        if model.elapsed != elapsed { model.elapsed = elapsed }
        if model.isPaused != paused { model.isPaused = paused }
    }

    /// Resuming, or the countdown ending: stay fully visible a moment before fading again.
    func noteActivity() {
        dimming.activity(at: Self.now)
    }

    func showCamera() {
        guard let view = panel.contentView else { return }
        let r = model.layout.expanded
        let rect = view.isFlipped ? r : NSRect(x: r.minX, y: view.bounds.height - r.maxY, width: r.width, height: r.height)
        RecordingControls.shared.showCamera(relativeTo: rect, of: view, preferredEdge: view.isFlipped ? .maxY : .minY)
    }

    /// Retracts into the notch. Recording has already stopped by now; this is only the visual.
    func retract() {
        guard isShown else { return }
        isShown = false
        generation += 1
        let gen = generation
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopHoverPolling()
        if targetAlpha < 1 { // Faded: come back first, so the retract can be seen
            targetAlpha = 1
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
        }
        let finish = { [weak self] in
            MainActor.assumeIsolated {
                guard let self, gen == self.generation else { return }
                self.panel.orderOut(nil)
            }
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            withAnimation(.easeIn(duration: 0.2)) { model.opacity = 0 } completion: { finish() }
        } else {
            withAnimation(.smooth(duration: 0.12)) { model.contentVisible = false }
            withAnimation(.smooth(duration: 0.35).delay(0.08)) { model.expanded = false } completion: { finish() }
        }
    }

    private func emerge(kind: RecordingKind, countdown: Int?) {
        guard let layout = Self.layout() else { return }
        generation += 1
        let gen = generation
        countdownTimer?.invalidate()
        countdownTimer = nil
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        model.layout = layout
        model.kind = kind
        model.countdown = countdown
        model.expanded = false
        model.contentVisible = false
        model.opacity = reduceMotion ? 0 : 1
        panel.setFrame(layout.windowFrame, display: false)
        panel.alphaValue = 1
        targetAlpha = 1
        panel.orderFrontRegardless()
        isShown = true
        isHovering = false
        dimming = CapsuleDimming(emergedAt: Self.now + Self.emergeDuration)
        startHoverPolling()
        // Start animating on the next pass, once the collapsed state (inside the notch) has been drawn
        DispatchQueue.main.async { [self] in
            guard gen == generation else { return }
            if reduceMotion {
                model.expanded = true
                model.contentVisible = true
                withAnimation(.easeOut(duration: 0.25)) { model.opacity = 1 }
            } else {
                withAnimation(.spring(duration: Self.emergeDuration, bounce: 0.3)) { model.expanded = true }
                withAnimation(.smooth(duration: 0.25).delay(Self.emergeDuration * 0.4)) { model.contentVisible = true }
            }
        }
    }

    private func relayout() {
        guard isShown, let layout = Self.layout() else { return }
        model.layout = layout
        panel.setFrame(layout.windowFrame, display: true)
    }

    /// The screen with the notch; without one, the screen that holds the menu bar.
    private static func layout() -> CapsuleLayout? {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first else { return nil }
        var notch: CGSize?
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        }
        // The menu bar may be hidden (full screen, or set to hide automatically): fall back to its usual height
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top, NSStatusBar.system.thickness)
        return CapsuleLayout.make(screenFrame: screen.frame, menuBarHeight: menuBarHeight, notch: notch, capsule: size)
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: Fading while the pointer is away

    // SwiftUI hover events are unreliable in a panel that isn't key, so the pointer position is polled instead
    private func startHoverPolling() {
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollHover() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func stopHoverPolling() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        setHovering(false)
    }

    private func pollHover() {
        guard model.expanded else { return }
        setHovering(model.layout.hoverArea.contains(NSEvent.mouseLocation))
        let idleOpacity = min(1, max(0.1, ud.double(forKey: "capsuleIdleOpacity")))
        let target = CGFloat(dimming.opacity(at: Self.now, idleOpacity: idleOpacity, countingDown: model.countdown != nil,
                                             paused: model.isPaused,
                                             reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency))
        guard abs(target - targetAlpha) > 0.001 else { return }
        let fadingIn = target > targetAlpha
        targetAlpha = target
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadingIn ? 0.15 : 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = target
        }
    }

    private func setHovering(_ inside: Bool) {
        guard inside != isHovering else { return }
        isHovering = inside
        dimming.pointer(isInside: inside, at: Self.now)
        // Keep the cursor highlight and the magnifier out of the way while using the capsule
        hideMousePointer = inside
        hideScreenMagnifier = inside
    }
}

final class CapsulePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Hands the first click straight to the button instead of spending it on activating the window.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

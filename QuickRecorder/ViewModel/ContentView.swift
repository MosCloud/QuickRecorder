//
//  ContentView.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI
import AVFoundation
import ScreenCaptureKit
import KeyboardShortcuts

/// The main panel (#48): the recording tiles at 90% of their original size, then Close over Preferences,
/// on the material the floating capsule uses.
struct ContentView: View {
    @State private var isDevicePopoverShowing = false
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = false
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    @Environment(\.colorScheme) private var colorScheme

    var appDelegate = AppDelegate.shared

    /// The panel's size against the original's 110×80 tiles
    private let k: CGFloat = 0.9

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14 * k, style: .continuous)
        // System Audio, the least used, comes last (#96)
        HStack {
            tile("Screen", "tv.inset.filled", hotkey: .startWithScreen) { appDelegate.chooseScreen() }
            separator
            tile("Screen Area", "viewfinder", hotkey: .startWithArea) { appDelegate.chooseArea() }
            separator
            tile("Application", "app", symbolSize: 38, overlayer: "App", hotkey: nil) { appDelegate.chooseApps() }
            separator
            tile("Window", "macwindow", hotkey: .startWithWindow) { appDelegate.chooseWindow() }
            separator
            tile("Mobile Device", "apps.ipad", hotkey: nil) { isDevicePopoverShowing = true }
                .popover(isPresented: $isDevicePopoverShowing, arrowEdge: .bottom) {
                    iDevicePopoverView(closePopover: {
                        // A device was chosen: its recording starts right away
                        isDevicePopoverShowing = false
                        MainPanelReturn.shared.startPressed()
                    })
                }
            separator
            tile("System Audio", "waveform", hotkey: .startWithAudio) { appDelegate.recordSystemAudio() }
            separator
            appButtons
        }
        .padding(.vertical, 10 * k)
        .padding(.horizontal, 20 * k)
        .environment(\.colorScheme, material == .black ? .dark : colorScheme)
        .background {
            background(shape)
                .contentShape(shape)
        }
        // Pressing anywhere moves the panel, tiles and buttons included; a click is still a click (#164)
        .dragWindowFromAnywhere()
        .allowsWindowActivationEvents(true)
        .fixedSize()
        .focusable(false)
    }

    private var separator: some View { Divider().frame(height: 70 * k) }

    /// A tile whose recording, or the setup for it, brings the panel back when it ends (#53)
    private func tile(_ title: String, _ symbol: String, symbolSize: CGFloat = 36, overlayer: String = "",
                      hotkey: KeyboardShortcuts.Name?, action: @escaping () -> Void) -> some View {
        RecordTile(title: title, symbol: symbol, symbolSize: symbolSize, overlayer: overlayer, hotkey: hotkey, scale: k) {
            MainPanelReturn.shared.tileChosen()
            action()
        }
    }

    /// Close over Preferences, a short rule between them as the dividers between the tiles; Quit beside Preferences when
    /// there is no Dock or menu bar icon to quit from. The microphone is in every capsule now, the System Audio tile's too (#96).
    private var appButtons: some View {
        VStack(spacing: 5 * k) {
            IconButton(symbol: "xmark.circle", help: "Close".local, size: 32 * k) { closeMainWindow() }
            Divider().frame(width: 22 * k)
            HStack(spacing: 2 * k) {
                IconButton(symbol: "gearshape", help: "Preferences".local, size: 32 * k) {
                    MainPanelReturn.shared.settingsOpened()
                    closeMainWindow()
                    appDelegate.openSettingPanel()
                }
                // A power symbol, so it doesn't read as a second Close
                if !showOnDock && !showMenubar {
                    IconButton(symbol: "power", help: "Quit".local, hoverTint: .darkMyRed, size: 32 * k) { NSApp.terminate(nil) }
                }
            }
        }
        .padding(.horizontal, 4 * k)
    }

    /// The floating capsule's three materials
    @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
        switch material {
        case .glass: Color.clear.glassEffect(.regular, in: shape)
        case .blur: shape.fill(.regularMaterial).environment(\.controlActiveState, .active)
        case .black: shape.fill(.black)
        }
    }
}

struct SelectorView: View {
    var title = "No Title".local
    var symbol = "app"
    var symbolSize: CGFloat = 36
    var overlayer = ""
    /// The menu bar panel's tile, about two-thirds the size
    var compact = false
    /// The main panel's tile, at this fraction of the original 110×80
    var scale: CGFloat = 1
    @State private var hovering = false

    var body: some View {
        let k = compact ? 0.84 : scale
        VStack(spacing: compact ? 5 : 6 * k) {
            Text(title)
                .opacity(0.95)
                .font(.system(size: compact ? 11 : 12 * k))
            ZStack {
                Image(systemName: symbol)
                    .opacity(0.95)
                    .font(.system(size: compact ? 24 : symbolSize * k))
                    .frame(height: compact ? 28 : 40 * k)
                Text(overlayer)
                    .fontWeight(.bold)
                    .opacity(0.95)
                    .font(.system(size: compact ? 7.5 : 11 * k))
            }
        }
        .frame(width: compact ? 92 : 110 * k, height: compact ? 60 : 80 * k)
        // A soft highlight, clear of the dividers, fading in and out (#48)
        .background {
            RoundedRectangle(cornerRadius: 10 * k, style: .continuous)
                .fill(.primary.opacity(hovering ? 0.1 : 0))
                .padding(3 * k)
                .animation(.easeOut(duration: 0.15), value: hovering)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct CountdownView: View {
    @State var countdownValue: Int = 00
    @State private var timer: Timer?
    var atEnd: () -> Void

    var body: some View {
        ZStack {
            Color.mypurple.environment(\.colorScheme, .dark)
            Text("\(countdownValue)")
                .font(.system(size: 72))
                .foregroundColor(.white)
                .offset(y: -10)
            Button(action: {
                timer?.invalidate()
                for w in NSApp.windows.filter({
                    $0.title == "Countdown Panel".local ||
                    $0.title == "Area Overlayer".local
                }) { w.close() }
                MainPanelReturn.shared.countdownCancelled()
            }, label: {
                ZStack {
                    Color.white.opacity(0.2)
                    Text("Cancel").foregroundColor(.white)
                }.frame(width: 120, height: 24)
            })
            .buttonStyle(.plain)
            .padding(.top, 96)
        }
        .frame(width: 120, height: 120)
        .cornerRadius(10)
        .onAppear{
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if countdownValue > 1 {
                    countdownValue -= 1
                } else {
                    timer.invalidate()
                    if let w = NSApp.windows.first(where: { $0.title == "Countdown Panel".local }) { w.close() }
                    atEnd()
                }
            }
        }
    }
}


/// The System Audio tile's capsule (#96): Close, the microphone and the timer, then Record
struct SystemAudioCapsule: View {
    @State private var nsWindow: NSWindow?
    let display: SCDisplay

    var body: some View {
        SelectorCapsule(leading: [CapsuleLeading(symbol: "xmark.circle", label: "Close".local, action: { nsWindow?.close() })],
                        screen: display.nsScreen, recordsVideo: false) { autoStop in
            closeAllWindow()
            AppDelegate.shared.countdownAndRecord(type: "audio", screen: display, autoStop: autoStop)
        }
        .background(WindowAccessor(onWindowOpen: { nsWindow = $0 }))
    }
}

extension AppDelegate {
    // What the tiles do, in the main panel and the menu bar panel alike

    /// A capsule first, as the other tiles open a picker; the hotkey and AppleScript still start right away
    func recordSystemAudio() {
        guard let display = SCContext.getSCDisplayWithMouse(), let screen = display.nsScreen else { return }
        closeMainWindow()
        MainActor.assumeIsolated {
            let panel = FloatingCapsulePanel.show(SystemAudioCapsule(display: display), title: "Start Recording".local,
                                                  centerX: screen.frame.midX, bottom: screen.visibleFrame.minY + 60)
            panel.onCancel = { [weak panel] in panel?.close() }
        }
    }

    func chooseScreen() {
        openPicker(ScreenSelector(), title: "Screen Selector".local)
    }

    func chooseArea() {
        closeMainWindow()
        SCContext.updateAvailableContent {
            DispatchQueue.main.async {
                self.showAreaSelector()
                var currentDisplay = SCContext.getSCDisplayWithMouse()
                mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .rightMouseDown, .leftMouseDown, .otherMouseDown]) { event in
                    let display = SCContext.getSCDisplayWithMouse()
                    if display != currentDisplay {
                        currentDisplay = display
                        closeAllWindow()
                        self.showAreaSelector()
                    }
                }
            }
        }
    }

    func chooseApps() {
        openPicker(AppSelector(), title: "App Selector".local)
    }

    func chooseWindow() {
        openPicker(WinSelector(), title: "Window Selector".local)
    }

    /// Brings the window selector back, for Esc and Close in its point-and-select mode (#116)
    @MainActor func showWindowSelector() {
        NSApp.activate()
        createNewWindow(view: WinSelector(), title: "Window Selector".local, closesOnEsc: true)
    }

    /// A tile's picker brings QuickRecorder to the front, so the picker takes the keys, Esc among them (#95).
    /// The panels the tiles sit on never activate it; a script's picker leaves the front app alone (#88)
    private func openPicker(_ view: some View, title: String) {
        closeMainWindow()
        NSApp.activate()
        createNewWindow(view: view, title: title, closesOnEsc: true)
    }

    /// 「编辑选区」 resizes the rectangle where it sits: rebuilding the overlay for every digit typed flashed the
    /// whole screen (#129)
    @MainActor func resizeAreaSelector(to size: NSSize) {
        for w in NSApp.windows where w.title == "Area Selector".local {
            (w.contentView as? ScreenshotOverlayView)?.apply(size: size)
        }
    }

    func showAreaSelector() {
        // The selector takes the keys, Esc among them: without this the app stays in the background and Esc goes
        // to whichever app is in front (#131)
        NSApp.activate()
        guard let scDisplay = SCContext.getSCDisplayWithMouse() else { return }
        guard let screen = scDisplay.nsScreen else { return }
        let screenshotWindow = ScreenshotWindow(contentRect: screen.frame, backing: .buffered, defer: false)
        screenshotWindow.title = "Area Selector".local
        (screenshotWindow.contentView as? ScreenshotOverlayView)?.frost(scDisplay)
        // The frost fades in as the selector opens (#97)
        screenshotWindow.alphaValue = 0
        screenshotWindow.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            screenshotWindow.animator().alphaValue = 1
        }
        MainActor.assumeIsolated {
            let panel = FloatingCapsulePanel.show(AreaSelector(screen: scDisplay), title: "Start Recording".local,
                                                  centerX: screen.frame.midX, bottom: screen.visibleFrame.minY + 60,
                                                  level: PickerShield.above)
            panel.onCancel = { [weak panel] in panel?.close() }
        }
    }
    func createCountdownPanel(screen: SCDisplay, action: @escaping () -> Void) {
        MainActor.assumeIsolated { MainPanelReturn.shared.startPressed() }
        guard let screen = screen.nsScreen else { return }
        let countdown = ud.integer(forKey: "countdown")
        if countdown == 0 {
            action()
        } else if MainActor.assumeIsolated({ RecordingControls.shared.capsuleEnabled }) {
            MainActor.assumeIsolated { RecordingControls.shared.capsule.runCountdown(seconds: countdown, then: action) }
        } else {
            let wX = (screen.frame.width - 120) / 2 + screen.frame.minX
            let wY = (screen.frame.height - 120) / 2 + screen.frame.minY
            let frame =  NSRect(x: wX, y: wY, width: 120, height: 120)
            let contentView = NSHostingView(rootView: CountdownView(countdownValue: countdown, atEnd: action))
            contentView.frame = frame
            countdownPanel.contentView = contentView
            countdownPanel.setFrame(frame, display: true)
            countdownPanel.makeKeyAndOrderFront(self)
        }
    }
    
    /// `closesOnEsc` for a picker: Esc closes it like its close button, and the main panel comes back as then (#95)
    func createNewWindow(view: some View, title: String, random: Bool = false, only: Bool = true, closesOnEsc: Bool = false) {
        // The pointer's screen can be missing, with the screen locked or asleep: this did nothing then (#72)
        guard let screen = SCContext.getScreenWithMouse() ?? NSScreen.main else { return }
        if only { closeAllWindow() }
        var seed = 0.0
        if random { seed = CGFloat(Int(arc4random_uniform(401)) - 200) }
        let wX = (screen.frame.width - 780) / 2 + seed + screen.frame.minX
        let wY = (screen.frame.height - 555) / 2 + 100 + seed + screen.frame.minY
        let contentView = NSHostingView(rootView: view)
        contentView.frame = NSRect(x: wX, y: wY, width: 780, height: 555)
        let windowClass: NSWindow.Type = closesOnEsc ? EscWindow.self : NSWindow.self
        let window = windowClass.init(contentRect: contentView.frame, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = title
        window.contentView = contentView
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(self)
        window.orderFrontRegardless()
    }
}

/// A window Esc closes, unless an open bubble of its capsule takes the Esc first
final class EscWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { close() }
}

extension View {
    func needScale() -> some View {
        return self.scaleEffect(0.8).padding(.leading, -4)
    }
}


/*#Preview {
    ContentView()
}
*/

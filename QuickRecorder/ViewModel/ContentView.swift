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

/// The main panel (#48): the recording tiles at 90% of their original size, then the microphone, Preferences and Quit,
/// on the material the floating capsule uses.
struct ContentView: View {
    @State private var isDevicePopoverShowing = false
    @State private var closeHovering = false
    @State private var micList = SCContext.getMicrophone()
    @AppStorage("recordMic") private var recordMic: Bool = false
    @AppStorage("micDevice") private var micDevice: String = "default"
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = false
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    @Environment(\.colorScheme) private var colorScheme

    var appDelegate = AppDelegate.shared

    /// The panel's size against the original's 110×80 tiles
    private let k: CGFloat = 0.9

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14 * k, style: .continuous)
        ZStack(alignment: .topLeading) {
            HStack {
                tile("System Audio", "waveform", hotkey: .startWithAudio) { appDelegate.recordSystemAudio() }
                separator
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
                microphoneAndApp
            }
            .padding(.vertical, 10 * k)
            .padding(.horizontal, 20 * k)
            Button {
                closeMainWindow()
            } label: {
                Image(systemName: "x.circle")
                    .font(.system(size: 13 * k, weight: .bold))
                    .opacity(closeHovering ? 1 : 0.4)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .onHover { closeHovering = $0 }
            .padding([.horizontal, .top], 7 * k)
        }
        .environment(\.colorScheme, material == .black ? .dark : colorScheme)
        .background {
            // An NSHostingView takes the mouse-down, so the panel's isMovableByWindowBackground alone moves nothing
            background(shape)
                .contentShape(shape)
                .gesture(WindowDragGesture())
        }
        .allowsWindowActivationEvents(true)
        .fixedSize()
        .focusable(false)
        .onChange(of: recordMic) { Task { await SCContext.performMicCheck() } }
        .onAppear {
            if micList.isEmpty { recordMic = false }
            if !micList.map({ $0.localizedName }).contains(micDevice) { micDevice = "default" }
        }
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

    /// The microphone over its device's name, a short divider, then Preferences and Quit side by side.
    /// The microphone applies to every recording, so it no longer sits under the System Audio tile.
    private var microphoneAndApp: some View {
        let device = micDevice == "default" ? "Default".local : micDevice
        return VStack(spacing: 4 * k) {
            MicToggle(isOn: $recordMic, size: 26 * k)
                .disabled(micList.isEmpty)
            Button {
                MicDeviceMenu.shared.show(devices: micList.map { $0.localizedName })
            } label: {
                HStack(spacing: 2) {
                    Text(device)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 70 * k)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!recordMic)
            .help(device)
            Divider().frame(width: 40 * k).padding(.vertical, 1)
            HStack(spacing: 2) {
                IconButton(symbol: "gearshape", help: "Preferences".local, size: 26 * k) {
                    closeMainWindow()
                    appDelegate.openSettingPanel()
                }
                // Otherwise there is no Dock or menu bar icon to quit from
                if !showOnDock && !showMenubar {
                    IconButton(symbol: "xmark.circle", help: "Quit".local, hoverTint: .darkMyRed, size: 26 * k) { NSApp.terminate(nil) }
                }
            }
        }
        .frame(width: 76 * k)
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


extension AppDelegate {
    // What the tiles do, in the main panel and the menu bar panel alike

    func recordSystemAudio() {
        guard let display = SCContext.getSCDisplayWithMouse() else { return }
        closeMainWindow()
        createCountdownPanel(screen: display) {
            AppDelegate.shared.prepRecord(type: "audio", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil)
        }
    }

    func chooseScreen() {
        closeMainWindow()
        createNewWindow(view: ScreenSelector(), title: "Screen Selector".local)
    }

    func chooseArea() {
        closeMainWindow()
        SCContext.updateAvailableContent {
            DispatchQueue.main.async {
                self.showAreaSelector(size: NSSize(width: 600, height: 450))
                var currentDisplay = SCContext.getSCDisplayWithMouse()
                mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .rightMouseDown, .leftMouseDown, .otherMouseDown]) { event in
                    let display = SCContext.getSCDisplayWithMouse()
                    if display != currentDisplay {
                        currentDisplay = display
                        closeAllWindow()
                        self.showAreaSelector(size: NSSize(width: 600, height: 450))
                    }
                }
            }
        }
    }

    func chooseApps() {
        closeMainWindow()
        createNewWindow(view: AppSelector(), title: "App Selector".local)
    }

    func chooseWindow() {
        closeMainWindow()
        createNewWindow(view: WinSelector(), title: "Window Selector".local)
    }

    func showAreaSelector(size: NSSize, noPanel: Bool = false) {
        guard let scDisplay = SCContext.getSCDisplayWithMouse() else { return }
        guard let screen = scDisplay.nsScreen else { return }
        let screenshotWindow = ScreenshotWindow(contentRect: screen.frame, backing: .buffered, defer: false, size: size, force: noPanel)
        screenshotWindow.title = "Area Selector".local
        //screenshotWindow.orderFront(self)
        screenshotWindow.orderFrontRegardless()
        if !noPanel {
            let wX = (screen.frame.width - 790) / 2 + screen.frame.minX
            let wY = screen.visibleFrame.minY + 80
            let contentView = NSHostingView(rootView: AreaSelector(screen: scDisplay))
            contentView.frame = NSRect(x: wX, y: wY, width: 790, height: 90)
            contentView.focusRingType = .none
            let areaPanel = NSPanel(contentRect: contentView.frame, styleMask: [.fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
            areaPanel.collectionBehavior = [.canJoinAllSpaces]
            areaPanel.setFrame(contentView.frame, display: true)
            areaPanel.level = .screenSaver
            areaPanel.title = "Start Recording".local
            areaPanel.contentView = contentView
            areaPanel.backgroundColor = .clear
            areaPanel.titleVisibility = .hidden
            areaPanel.isReleasedWhenClosed = false
            areaPanel.titlebarAppearsTransparent = true
            areaPanel.isMovableByWindowBackground = true
            //areaPanel.setFrameOrigin(NSPoint(x: wX, y: wY))
            areaPanel.orderFront(self)
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
    
    func createNewWindow(view: some View, title: String, random: Bool = false, only: Bool = true) {
        guard let screen = SCContext.getScreenWithMouse() else { return }
        if only { closeAllWindow() }
        var seed = 0.0
        if random { seed = CGFloat(Int(arc4random_uniform(401)) - 200) }
        let wX = (screen.frame.width - 780) / 2 + seed + screen.frame.minX
        let wY = (screen.frame.height - 555) / 2 + 100 + seed + screen.frame.minY
        let contentView = NSHostingView(rootView: view)
        contentView.frame = NSRect(x: wX, y: wY, width: 780, height: 555)
        let window = NSWindow(contentRect: contentView.frame, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
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

extension View {
    func needScale() -> some View {
        return self.scaleEffect(0.8).padding(.leading, -4)
    }
}


/*#Preview {
    ContentView()
}
*/

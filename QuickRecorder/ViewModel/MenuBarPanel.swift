//
//  MenuBarPanel.swift
//  QuickRecorder
//
//  What the menu bar item opens while idle (#46): the main panel's tiles at about two-thirds size and in its order,
//  over one line of icon buttons: the microphone switch with its device, Preferences and Quit. The controls are in PanelControls.swift.
//

import SwiftUI
import AVFoundation
import KeyboardShortcuts

struct MenuBarPanel: View {
    var close: () -> Void
    @State private var isDevicePopoverShowing = false
    @State private var micList = SCContext.getMicrophone()
    @AppStorage("recordMic") private var recordMic: Bool = false
    @AppStorage("micDevice") private var micDevice: String = "default"

    var appDelegate = AppDelegate.shared

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    tile("System Audio", "waveform", hotkey: .startWithAudio) { appDelegate.recordSystemAudio() }
                    separator
                    tile("Screen", "tv.inset.filled", hotkey: .startWithScreen) { appDelegate.chooseScreen() }
                    separator
                    tile("Screen Area", "viewfinder", hotkey: .startWithArea) { appDelegate.chooseArea() }
                }
                HStack(spacing: 9) {
                    // A divider is vertical inside an HStack; the VStack around each makes it horizontal
                    ForEach(0..<3, id: \.self) { _ in VStack { Divider() }.frame(width: 76).frame(width: 92) }
                }
                HStack(spacing: 4) {
                    tile("Application", "app", overlayer: "App", hotkey: nil) { appDelegate.chooseApps() }
                    separator
                    tile("Window", "macwindow", hotkey: .startWithWindow) { appDelegate.chooseWindow() }
                    separator
                    RecordTile(title: "Mobile Device", symbol: "apps.ipad", compact: true) { isDevicePopoverShowing = true }
                    .popover(isPresented: $isDevicePopoverShowing, arrowEdge: .bottom) {
                        iDevicePopoverView(closePopover: { isDevicePopoverShowing = false; close() })
                    }
                }
            }
            .padding(8)
            Divider()
            HStack(spacing: 4) {
                MicToggle(isOn: $recordMic)
                    .disabled(micList.isEmpty)
                Picker("", selection: $micDevice) {
                    Text("Default".local).tag("default")
                    ForEach(micList, id: \.self) { device in
                        Text(device.localizedName).tag(device.localizedName)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                .disabled(!recordMic)
                Spacer()
                IconButton(symbol: "gearshape", help: "Preferences".local) {
                    close()
                    appDelegate.openSettingPanel()
                }
                IconButton(symbol: "xmark.circle", help: "Quit".local, hoverTint: .darkMyRed) { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .fixedSize()
        .onChange(of: recordMic) { Task { await SCContext.performMicCheck() } }
        .onAppear {
            if micList.isEmpty { recordMic = false }
            if !micList.map({ $0.localizedName }).contains(micDevice) { micDevice = "default" }
        }
    }

    private var separator: some View { Divider().frame(height: 46) }

    /// A tile that closes the panel and does what the same tile does in the main panel.
    private func tile(_ title: String, _ symbol: String, overlayer: String = "", hotkey: KeyboardShortcuts.Name?,
                      action: @escaping () -> Void) -> some View {
        RecordTile(title: title, symbol: symbol, overlayer: overlayer, hotkey: hotkey, compact: true) {
            close()
            action()
        }
    }
}

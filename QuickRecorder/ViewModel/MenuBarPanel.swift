//
//  MenuBarPanel.swift
//  QuickRecorder
//
//  What the menu bar item opens while idle (#46): the main panel's tiles at about two-thirds size and in its order,
//  over one line of icon buttons: the microphone switch with its device, Preferences and Quit.
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
                    Button {
                        isDevicePopoverShowing = true
                    } label: {
                        SelectorView(title: "Mobile Device".local, symbol: "apps.ipad", compact: true).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
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

    /// A tile that closes the panel and does what the same tile does in the main panel; hovering shows its hotkey.
    private func tile(_ title: String, _ symbol: String, overlayer: String = "", hotkey: KeyboardShortcuts.Name?,
                      action: @escaping () -> Void) -> some View {
        Button {
            close()
            action()
        } label: {
            SelectorView(title: title.local, symbol: symbol, overlayer: overlayer, compact: true).cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(hotkey.flatMap { KeyboardShortcuts.getShortcut(for: $0)?.description } ?? "")
    }
}

/// The microphone is its own switch: a green mic while on, a grey slashed mic while off.
struct MicToggle: View {
    @Binding var isOn: Bool
    @State private var hovering = false
    @State private var bounces = 0

    /// 1.5× the system speed for symbol effects; the owner found 1× slow (#46)
    private let speed = 1.5

    var body: some View {
        Button {
            isOn.toggle()
            if isOn { bounces += 1 }
        } label: {
            Image(systemName: isOn ? "mic.fill" : "mic.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace, options: .speed(speed)))
                .symbolEffect(.bounce, options: .speed(speed), value: bounces)
                .frame(width: 26, height: 26)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
                .animation(.smooth(duration: 0.2 / speed), value: isOn)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Microphone".local)
        .accessibilityLabel("Microphone".local)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// An icon-only button: secondary until hovered, then a round highlight and `hoverTint`.
struct IconButton: View {
    let symbol: String
    let help: String
    var hoverTint: Color = .primary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(hovering ? AnyShapeStyle(hoverTint) : AnyShapeStyle(.secondary))
                .frame(width: 26, height: 26)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

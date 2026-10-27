//
//  PanelControls.swift
//  QuickRecorder
//
//  Controls the main panel and the menu bar panel share (#46, #48).
//

import SwiftUI
import KeyboardShortcuts

/// A recording tile: the main panel's look, its hotkey on hover, and a little give when pressed.
struct RecordTile: View {
    let title: String
    let symbol: String
    var symbolSize: CGFloat = 36
    var overlayer = ""
    var hotkey: KeyboardShortcuts.Name?
    var compact = false
    var scale: CGFloat = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SelectorView(title: title.local, symbol: symbol, symbolSize: symbolSize, overlayer: overlayer, compact: compact, scale: scale)
        }
        .buttonStyle(TilePress())
        .help(hotkey.flatMap { KeyboardShortcuts.getShortcut(for: $0)?.description } ?? "")
    }
}

/// Pressing a tile shrinks it a little, until released.
struct TilePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// The microphone is its own switch: a green mic while on, a grey slashed mic while off.
struct MicToggle: View {
    @Binding var isOn: Bool
    var size: CGFloat = 26
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
                .font(.system(size: 14 * size / 26, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace, options: .speed(speed)))
                .symbolEffect(.bounce, options: .speed(speed), value: bounces)
                .frame(width: size, height: size)
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
    var size: CGFloat = 26
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15 * size / 26))
                .foregroundStyle(hovering ? AnyShapeStyle(hoverTint) : AnyShapeStyle(.secondary))
                .frame(width: size, height: size)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Pops up the microphones under the pointer, with a checkmark on the chosen one. Drawn by AppKit:
/// SwiftUI's Menu restyles a custom label, and the device's name has to stay small.
@MainActor
final class MicDeviceMenu: NSObject {
    static let shared = MicDeviceMenu()

    func show(devices: [String]) {
        let selected = ud.string(forKey: "micDevice") ?? "default"
        let menu = NSMenu()
        for (title, tag) in [("Default".local, "default")] + devices.map({ ($0, $0) }) {
            let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            item.state = tag == selected ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func choose(_ sender: NSMenuItem) {
        ud.set(sender.representedObject as? String, forKey: "micDevice")
    }
}

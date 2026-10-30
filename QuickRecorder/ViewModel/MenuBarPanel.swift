//
//  MenuBarPanel.swift
//  QuickRecorder
//
//  What the menu bar item opens while idle (#46): the main panel's five recording tiles at about two-thirds size and in
//  its order, and Quit where the device tile used to be. Preferences lives in the main panel only, and nothing here has
//  a tooltip (#183, #184). The controls are in PanelControls.swift.
//

import SwiftUI
import AVFoundation
import KeyboardShortcuts

struct MenuBarPanel: View {
    var close: () -> Void

    var appDelegate = AppDelegate.shared

    var body: some View {
        VStack(spacing: 4) {
            // The main panel's order: System Audio, the least used, comes last (#96)
            HStack(spacing: 4) {
                tile("Screen", "tv.inset.filled", hotkey: .startWithScreen) { appDelegate.chooseScreen() }
                separator
                tile("Screen Area", "viewfinder", hotkey: .startWithArea) { appDelegate.chooseArea() }
                separator
                tile("Application", "app", overlayer: "App", hotkey: nil) { appDelegate.chooseApps() }
            }
            HStack(spacing: 9) {
                // A divider is vertical inside an HStack; the VStack around each makes it horizontal
                ForEach(0..<3, id: \.self) { _ in VStack { Divider() }.frame(width: 76).frame(width: 92) }
            }
            HStack(spacing: 4) {
                tile("Window", "macwindow", hotkey: .startWithWindow) { appDelegate.chooseWindow() }
                separator
                // Mobile Device is in the main panel only (#183)
                tile("System Audio", "waveform", hotkey: .startWithAudio) { appDelegate.recordSystemAudio() }
                separator
                QuitButton().frame(width: 92, height: 60)
            }
        }
        .padding(8)
        .fixedSize()
    }

    private var separator: some View { Divider().frame(height: 46) }

    /// A tile that closes the panel and does what the same tile does in the main panel. No tooltip: this panel is for
    /// quick actions, and a hint popping up over it gets in the way (#184).
    private func tile(_ title: String, _ symbol: String, overlayer: String = "", hotkey: KeyboardShortcuts.Name?,
                      action: @escaping () -> Void) -> some View {
        RecordTile(title: title, symbol: symbol, overlayer: overlayer, hotkey: hotkey, compact: true, showsHelp: false) {
            // The picker takes the main panel's place: the old panel steps aside, but backing out of the picker brings
            // it back, the same as a tile pressed in the main panel (#203)
            MainPanelReturn.shared.menuBarPanelTileChosen()
            close()
            // A tile is a user action here too: the one activation a picker asks for, so the menu bar can come off
            // (#170)
            NSApp.activate()
            action()
        }
    }
}

/// The panel's Quit button (#183): grey until the pointer is on it, then red with a faint glow, so it reads as the
/// destructive action without competing with the recording tiles. No tooltip (#184).
private struct QuitButton: View {
    /// Fills its 92×60 cell without touching its edges
    private static let size: CGFloat = 34
    @State private var hovering = false

    var body: some View {
        Button { NSApp.terminate(nil) } label: {
            Image(systemName: "power")
                .font(.system(size: 15 * Self.size / 26))
                .foregroundStyle(hovering ? AnyShapeStyle(Color(nsColor: .systemRed)) : AnyShapeStyle(.secondary))
                .frame(width: Self.size, height: Self.size)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
                .shadow(color: hovering ? Color(nsColor: .systemRed).opacity(0.55) : .clear, radius: hovering ? 4 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Quit".local)
    }
}

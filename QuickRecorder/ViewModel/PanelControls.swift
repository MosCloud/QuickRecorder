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
    /// The menu bar panel shows no tooltips (#184)
    var showsHelp = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SelectorView(title: title.local, symbol: symbol, symbolSize: symbolSize, overlayer: overlayer, compact: compact, scale: scale)
        }
        .buttonStyle(TilePress())
        .helpIfPresent(showsHelp ? hotkey.flatMap { KeyboardShortcuts.getShortcut(for: $0)?.description } : nil)
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

/// An icon-only button: secondary until hovered, then a round highlight and `hoverTint`.
struct IconButton: View {
    let symbol: String
    let help: String
    var hoverTint: Color = .primary
    var size: CGFloat = 26
    /// The menu bar panel shows no tooltips (#184)
    var showsHelp = true
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
        .helpIfPresent(showsHelp ? help : nil)
        .accessibilityLabel(help)
    }
}

extension View {
    /// A tooltip only when it has something to say: the menu bar panel shows none (#184)
    @ViewBuilder
    func helpIfPresent(_ text: String?) -> some View {
        if let text, !text.isEmpty { self.help(text) } else { self }
    }
}

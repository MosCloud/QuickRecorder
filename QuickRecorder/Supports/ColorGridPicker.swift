//
//  ColorGridPicker.swift
//  QuickRecorder
//
//  Picks the custom background colour: a swatch button that opens a grid of colours chosen to work
//  as recording backgrounds, with a preview of an app window on the colour under the pointer.
//

import SwiftUI

struct ColorGridPicker: View {
    @Binding var selection: Color
    @State private var isShowing = false
    @State private var hovered: Swatch?

    var body: some View {
        Button { isShowing.toggle() } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(selection)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.primary.opacity(0.2), lineWidth: 0.5))
                    .frame(width: 30, height: 16)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing, arrowEdge: .bottom) { grid }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The colour under the pointer, otherwise the chosen one
            BackgroundPreview(color: hovered?.color ?? selection)
            Text(hovered?.name.local ?? "Current Color".local)
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 20), count: 4), spacing: 10) {
                ForEach(Swatch.all) { swatch in
                    ZStack {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                        if swatch.matches(selection) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(swatch.isLight ? .black : .white)
                        }
                    }
                    .scaleEffect(hovered?.id == swatch.id ? 1.12 : 1)
                    .animation(.smooth(duration: 0.12), value: hovered?.id)
                    .help(swatch.name.local)
                    .onHover { inside in
                        if inside { hovered = swatch } else if hovered?.id == swatch.id { hovered = nil }
                    }
                    .onTapGesture {
                        selection = swatch.color
                        isShowing = false
                    }
                }
            }
            Divider()
            Button("More Colors…") {
                isShowing = false
                ColorPanel.shared.open(color: selection) { selection = $0 }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 192)
        .onDisappear { hovered = nil }
    }
}

/// A mock app window on the background colour, as an application recording would show it.
private struct BackgroundPreview: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 6, height: 6) }
                    Spacer()
                }
                .padding(5)
                .background(Color(white: 0.93))
                Color.white
            }
            .frame(width: 90, height: 57)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .frame(width: 164, height: 92)
        .animation(.smooth(duration: 0.15), value: color)
    }
}

private struct Swatch: Identifiable {
    let name: String
    let hex: UInt32

    var id: UInt32 { hex }
    var color: Color { Color(nsColor: nsColor) }
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    /// Light enough that the checkmark on it is drawn black.
    var isLight: Bool { 0.299 * nsColor.redComponent + 0.587 * nsColor.greenComponent + 0.114 * nsColor.blueComponent > 0.6 }

    func matches(_ color: Color) -> Bool {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return false }
        let rgb = [c.redComponent, c.greenComponent, c.blueComponent].map { UInt32(($0 * 255).rounded()) }
        return rgb[0] << 16 | rgb[1] << 8 | rgb[2] == hex
    }

    // Calm colours that suit a recording background, then a few deeper ones
    static let all: [Swatch] = [
        .init(name: "White", hex: 0xFFFFFF), .init(name: "Light Gray", hex: 0xE5E5EA), .init(name: "Graphite", hex: 0x3A3A3C), .init(name: "Black", hex: 0x000000),
        .init(name: "Mist Blue", hex: 0xA9C4E2), .init(name: "Mint", hex: 0xB9E0D0), .init(name: "Apricot", hex: 0xF4D6B0), .init(name: "Lavender", hex: 0xCDB8DE),
        .init(name: "Warm Gray", hex: 0xD8D3C8), .init(name: "Pink", hex: 0xF2C4CB), .init(name: "Sky Blue", hex: 0x7EC8F0), .init(name: "Bright Blue", hex: 0x0A84FF),
        .init(name: "Navy", hex: 0x1F3A5F), .init(name: "Forest Green", hex: 0x2E5E4E), .init(name: "Wine", hex: 0x6D2E46), .init(name: "Midnight", hex: 0x14161F),
    ]
}

/// Opens the system colour panel for "More Colors…" and reports what it picks.
@MainActor
private final class ColorPanel: NSObject {
    static let shared = ColorPanel()
    private var onChange: ((Color) -> Void)?

    func open(color: Color, onChange: @escaping (Color) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = NSColor(color)
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        panel.orderFront(nil)
    }

    @objc private func changed(_ sender: NSColorPanel) {
        onChange?(Color(nsColor: sender.color))
    }
}

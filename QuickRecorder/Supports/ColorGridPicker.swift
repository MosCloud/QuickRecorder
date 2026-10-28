//
//  ColorGridPicker.swift
//  QuickRecorder
//
//  The custom background colour, right in the selectors' Options bubble (#92; it was a popover in Settings, #36):
//  colours chosen to work as recording backgrounds, in the bubble's swatch style, and the system colour panel for
//  any other.
//

import SwiftUI

struct ColorGridPicker: View {
    @Binding var selection: Color

    var body: some View {
        // Two rows of eight, the last cell opening the colour panel
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 2), count: 8), alignment: .leading, spacing: 2) {
            ForEach(Swatch.all) { swatch in
                Button { withAnimation(.smooth(duration: 0.2)) { choose(swatch.color) } } label: {
                    Circle().fill(swatch.color).frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.25), lineWidth: 0.5))
                        .padding(3)
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: swatch.matches(selection) ? 2 : 0))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.name.local)
            }
            Button { ColorPanel.shared.open(color: selection) { choose($0) } } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.quaternary))
                    .padding(3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More Colors…".local)
        }
        .frame(width: 8 * 22 + 7 * 2, alignment: .leading)
    }

    private func choose(_ color: Color) {
        selection = color
        ud.setColor(color, forKey: "userColor")
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

    func matches(_ color: Color) -> Bool {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return false }
        let rgb = [c.redComponent, c.greenComponent, c.blueComponent].map { UInt32(($0 * 255).rounded()) }
        return rgb[0] << 16 | rgb[1] << 8 | rgb[2] == hex
    }

    // Calm colours that suit a recording background, then a few deeper ones. White and black are in the row above
    static let all: [Swatch] = [
        .init(name: "Light Gray", hex: 0xE5E5EA), .init(name: "Warm Gray", hex: 0xD8D3C8), .init(name: "Graphite", hex: 0x3A3A3C), .init(name: "Midnight", hex: 0x14161F),
        .init(name: "Mist Blue", hex: 0xA9C4E2), .init(name: "Sky Blue", hex: 0x7EC8F0), .init(name: "Bright Blue", hex: 0x0A84FF), .init(name: "Navy", hex: 0x1F3A5F),
        .init(name: "Mint", hex: 0xB9E0D0), .init(name: "Sage", hex: 0xA8BBA3), .init(name: "Forest Green", hex: 0x2E5E4E), .init(name: "Apricot", hex: 0xF4D6B0),
        .init(name: "Pink", hex: 0xF2C4CB), .init(name: "Lavender", hex: 0xCDB8DE), .init(name: "Wine", hex: 0x6D2E46),
    ]
}

/// Opens the system colour panel for any other colour and reports what it picks.
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

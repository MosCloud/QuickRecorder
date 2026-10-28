//
//  ColorGridPicker.swift
//  QuickRecorder
//
//  What the custom background colour window holds (#117): a preview of an app window on the colour, the colours chosen
//  to work as recording backgrounds, and the system colour panel in the grid's last cell. It was the picker inside the
//  selectors' Options bubble (#92), which grew into this window when the preview and the panel joined it.
//

import SwiftUI

struct BackgroundColorWindow: View {
    @ObservedObject var model: CustomColorModel
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Background Color".local).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { ColorWindow.shared.close() } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close".local)
            }
            .frame(height: 18)

            // An app window on the colour: the pointer over a swatch previews it
            BackgroundPreview(color: model.shown)
                .frame(width: 288, height: 118)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 8), spacing: 8) {
                ForEach(Swatch.all) { swatch in
                    Button { model.choose(swatch) } label: {
                        ZStack {
                            Circle().fill(swatch.color)
                                .overlay(Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 0.5))
                            if swatch.matches(model.color) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(swatch.isLight ? .black : .white)
                            }
                        }
                        .frame(width: 26, height: 26)
                        .scaleEffect(model.hovered?.id == swatch.id ? 1.12 : 1)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name.local)
                    .onHover { inside in
                        if inside { model.hovered = swatch }
                        else if model.hovered?.id == swatch.id { model.hovered = nil }
                    }
                }
                // Not a colour of its own, but the way to any other: the system's panel, in the last cell
                SystemColorCell()
                    .frame(width: 26, height: 26)
            }
            .frame(width: 264)
            .onDisappear { model.hovered = nil }
        }
        .padding(16)
        .background { chrome }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
        }
        .environment(\.colorScheme, material == .black ? .dark : colorScheme)
        .fixedSize()
    }

    /// Glass only shows its active look in a key window, which this one can never be: the blur stands in for it
    @ViewBuilder private var chrome: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if material == .black {
            shape.fill(Color.black)
        } else {
            shape.fill(.regularMaterial).environment(\.controlActiveState, .active)
        }
    }
}

/// A mock app window on the background colour, as an application recording would show it
struct BackgroundPreview: View {
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
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background(Color(white: 0.93))
                Color.white
            }
            .frame(width: 190, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        }
        .frame(width: 288, height: 118)
        .animation(.smooth(duration: 0.15), value: color)
    }
}

/// The grid's last cell: the system colour panel, which never closes the bubble it was opened under
private struct SystemColorCell: View {
    @State private var hovering = false

    var body: some View {
        Button { SystemColorPanel.shared.open() } label: {
            ZStack {
                Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
                Circle().strokeBorder(.primary.opacity(0.22), lineWidth: 0.5)
                // A white centre, the way a colour wheel reads rather than a colour one can pick
                Circle().fill(.white).frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
            }
            .frame(width: 26, height: 26)
            .scaleEffect(hovering ? 1.12 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("More Colors…".local)
    }
}

/// Opens the system colour panel and reports what it picks; it needn't take key for a click on a swatch
@MainActor
private final class SystemColorPanel: NSObject {
    static let shared = SystemColorPanel()

    func open() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = NSColor(ColorWindow.shared.model.color)
        // Clicking a swatch needs no keyboard, so the selector's window keeps key and its Liquid Glass its active look
        panel.becomesKeyOnlyIfNeeded = true
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        panel.orderFront(nil)
    }

    @objc private func changed(_ sender: NSColorPanel) {
        ColorWindow.shared.model.color = Color(nsColor: sender.color)
    }
}

struct Swatch: Identifiable {
    let name: String
    let hex: UInt32

    var id: UInt32 { hex }
    var color: Color { Color(nsColor: nsColor) }
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    /// Light enough that the checkmark on it is drawn black
    var isLight: Bool {
        0.299 * nsColor.redComponent + 0.587 * nsColor.greenComponent + 0.114 * nsColor.blueComponent > 0.6
    }

    func matches(_ color: Color) -> Bool {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return false }
        let rgb = [c.redComponent, c.greenComponent, c.blueComponent].map { UInt32(($0 * 255).rounded()) }
        return rgb[0] << 16 | rgb[1] << 8 | rgb[2] == hex
    }

    // Calm colours that suit a recording background, then a few deeper ones
    static let all: [Swatch] = [
        .init(name: "Light Gray", hex: 0xE5E5EA), .init(name: "Warm Gray", hex: 0xD8D3C8), .init(name: "Graphite", hex: 0x3A3A3C), .init(name: "Midnight", hex: 0x14161F),
        .init(name: "Mist Blue", hex: 0xA9C4E2), .init(name: "Sky Blue", hex: 0x7EC8F0), .init(name: "Bright Blue", hex: 0x0A84FF), .init(name: "Navy", hex: 0x1F3A5F),
        .init(name: "Mint", hex: 0xB9E0D0), .init(name: "Sage", hex: 0xA8BBA3), .init(name: "Forest Green", hex: 0x2E5E4E), .init(name: "Apricot", hex: 0xF4D6B0),
        .init(name: "Pink", hex: 0xF2C4CB), .init(name: "Lavender", hex: 0xCDB8DE), .init(name: "Wine", hex: 0x6D2E46),
    ]
}

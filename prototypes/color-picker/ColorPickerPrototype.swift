// PROTOTYPE — 一次性代码，不属于 QuickRecorder 的 app target。
//
// 第 1 轮结论：选色界面用方案 C「弹出色板」（4×4 精选色 + 更多颜色…）。
// 第 2 轮问题：「效果预览」（一个模拟的应用窗口放在所选颜色上）放在哪里？
//   C1 弹窗顶部：鼠标移到色块上就预览，点击才选中；设置页不变高
//   C2 设置页常驻：预览一直显示在这一行下面，弹窗里只有色板
//   C3 两处都有
// 窗口仿照设置页的「录制设置」一组；底部 ◀ ▶ 或键盘 ← → 切换方案。
//
// 运行：prototypes/color-picker/run.sh

import AppKit
import SwiftUI

enum Variant: Int, CaseIterable {
    case popover, inline, both

    var title: String {
        switch self {
        case .popover: "C1 弹窗顶部预览（悬停即预览）"
        case .inline: "C2 设置页常驻预览"
        case .both: "C3 两处都有"
        }
    }
    var previewInPopover: Bool { self != .inline }
    var previewInSettings: Bool { self != .popover }
}

/// 挑给录像背景用的 16 个颜色
struct Swatch: Identifiable {
    let name: String
    let hex: UInt32
    var id: UInt32 { hex }
    var color: Color { Color(nsColor: nsColor) }
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    var isLight: Bool {
        let c = nsColor
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.6
    }

    static let all: [Swatch] = [
        .init(name: "白", hex: 0xFFFFFF), .init(name: "浅灰", hex: 0xE5E5EA), .init(name: "石墨", hex: 0x3A3A3C), .init(name: "黑", hex: 0x000000),
        .init(name: "雾蓝", hex: 0xA9C4E2), .init(name: "薄荷", hex: 0xB9E0D0), .init(name: "杏色", hex: 0xF4D6B0), .init(name: "淡紫", hex: 0xCDB8DE),
        .init(name: "暖灰", hex: 0xD8D3C8), .init(name: "粉", hex: 0xF2C4CB), .init(name: "天蓝", hex: 0x7EC8F0), .init(name: "苹果蓝", hex: 0x0A84FF),
        .init(name: "深海蓝", hex: 0x1F3A5F), .init(name: "森林绿", hex: 0x2E5E4E), .init(name: "酒红", hex: 0x6D2E46), .init(name: "午夜", hex: 0x14161F),
    ]
}

@MainActor
final class Demo: ObservableObject {
    @Published var variant = Variant.popover
    @Published var color = Swatch.all[4].nsColor

    var hex: String {
        let c = color.usingColorSpace(.sRGB) ?? color
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }

    func isSelected(_ swatch: Swatch) -> Bool { hex == String(format: "#%06X", swatch.hex) }
}

/// 打开系统颜色面板，选的颜色回写到 Demo（「更多颜色…」用）
@MainActor
final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    weak var demo: Demo?

    func open(for demo: Demo) {
        self.demo = demo
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = demo.color
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        panel.orderFront(nil)
    }

    @objc func changed(_ sender: NSColorPanel) { demo?.color = sender.color }
}

/// 效果预览：一个模拟的应用窗口放在背景色上
struct BackgroundPreview: View {
    let color: NSColor
    let size: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(nsColor: color))
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
            .frame(width: size.width * 0.55, height: size.height * 0.62)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .frame(width: size.width, height: size.height)
        .animation(.smooth(duration: 0.15), value: color)
    }
}

/// 方案 C：颜色按钮 + 弹出色板
struct ColorGridRow: View {
    @ObservedObject var demo: Demo
    @State private var showing = false
    @State private var hovered: Swatch?

    var body: some View {
        HStack {
            Text("用户预设颜色 (自定义背景)")
            Spacer()
            Button { showing.toggle() } label: {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(nsColor: demo.color))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.primary.opacity(0.2), lineWidth: 0.5))
                        .frame(width: 30, height: 16)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showing, arrowEdge: .bottom) { grid }
        }
        .frame(height: 16)
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 10) {
            if demo.variant.previewInPopover {
                BackgroundPreview(color: hovered?.nsColor ?? demo.color, size: CGSize(width: 164, height: 92))
                Text(hovered?.name ?? "当前颜色").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 20), count: 4), spacing: 10) {
                ForEach(Swatch.all) { swatch in
                    ZStack {
                        Circle().fill(swatch.color).frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                        if demo.isSelected(swatch) {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(swatch.isLight ? .black : .white)
                        }
                    }
                    .scaleEffect(hovered?.id == swatch.id ? 1.12 : 1)
                    .animation(.smooth(duration: 0.12), value: hovered?.id)
                    .help(swatch.name)
                    .onHover { inside in
                        if inside { hovered = swatch } else if hovered?.id == swatch.id { hovered = nil }
                    }
                    .onTapGesture { demo.color = swatch.nsColor; showing = false }
                }
            }
            Divider()
            Button("更多颜色…") { showing = false; ColorPanelBridge.shared.open(for: demo) }
                .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 192)
        .onDisappear { hovered = nil }
    }
}

// MARK: - 窗口：仿设置页的一组 + 切换栏

struct PrototypeView: View {
    @ObservedObject var demo: Demo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("录制设置").font(.headline)) {
                VStack(spacing: 10) {
                    HStack { Text("开始录制前倒数 (秒)"); Spacer(); Text("0").monospacedDigit().foregroundStyle(.secondary) }
                        .frame(height: 16)
                    Divider().opacity(0.5)
                    ColorGridRow(demo: demo)
                    if demo.variant.previewInSettings {
                        HStack {
                            Spacer()
                            BackgroundPreview(color: demo.color, size: CGSize(width: 220, height: 110))
                        }
                    }
                }
                .padding(5)
            }
            GroupBox(label: Text("录制控制").font(.headline)) {
                HStack { Text("菜单栏计时 + 菜单"); Spacer(); Toggle("", isOn: .constant(true)).toggleStyle(.switch).controlSize(.small) }
                    .padding(5)
            }
            .opacity(0.5)

            HStack(spacing: 12) {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                Text(demo.variant.title).frame(maxWidth: .infinity)
                Button { step(1) } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 13, weight: .semibold))
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.8)))
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            Text("当前颜色：\(demo.hex)。点右边的颜色按钮打开色板；C1、C3 在色板里把鼠标移到色块上就能预览。")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 460)
        .animation(.smooth(duration: 0.2), value: demo.variant)
    }

    private func step(_ by: Int) {
        let all = Variant.allCases
        demo.variant = all[(demo.variant.rawValue + by + all.count) % all.count]
        print("→ \(demo.variant.title)")
    }
}

@main
@MainActor
final class PrototypeApp: NSObject, NSApplicationDelegate {
    private let demo = Demo()
    private var window: NSWindow?

    static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        let app = NSApplication.shared
        let delegate = PrototypeApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingView(rootView: PrototypeView(demo: demo))
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420), styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "PROTOTYPE · 自定义背景色（第 2 轮：效果预览放哪里）"
        window.contentView = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, event.keyCode == 123 || event.keyCode == 124 else { return }
                let all = Variant.allCases
                self.demo.variant = all[(self.demo.variant.rawValue + (event.keyCode == 123 ? -1 : 1) + all.count) % all.count]
            }
            return event
        }
        NSApp.activate()
        print("第 2 轮原型已启动：底部 ◀ ▶ 或键盘 ← → 切换方案；关掉窗口退出。")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

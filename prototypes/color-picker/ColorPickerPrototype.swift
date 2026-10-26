// PROTOTYPE — 一次性代码，不属于 QuickRecorder 的 app target。
//
// 问题：设置 → 录制设置 →「用户预设颜色（自定义背景）」用什么样的选色界面？
// 窗口里仿照设置页的「录制设置」一组，这一行可以换成四个方案（底部 ◀ ▶ 或键盘 ← →）。
// 下面的「效果预览」把一个模拟的应用窗口放在所选颜色上，看这个颜色适不适合做录像背景。
//
// 运行：prototypes/color-picker/run.sh

import AppKit
import SwiftUI

enum Variant: Int, CaseIterable {
    case current, swatchRow, popoverGrid, minimalWell

    var title: String {
        switch self {
        case .current: "A 现状：原生取色器（点开是系统颜色面板）"
        case .swatchRow: "B 系统设置式色板：一排圆点 + 自定义"
        case .popoverGrid: "C 弹出色板：4×4 精选色 + 更多颜色…"
        case .minimalWell: "D 系统精简样式：NSColorWell minimal"
        }
    }
}

/// 挑给录像背景用的颜色：前 8 个放在 B 的一排里，16 个全部放在 C 的色板里
struct Swatch: Identifiable {
    let name: String
    let hex: UInt32
    var id: UInt32 { hex }
    var color: Color { Color(nsColor: nsColor) }
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
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
    @Published var variant = Variant.current
    @Published var color = Swatch.all[3].nsColor

    var hex: String {
        let c = color.usingColorSpace(.sRGB) ?? color
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }

    func isSelected(_ swatch: Swatch) -> Bool { hex == String(format: "#%06X", swatch.hex) }
}

/// 打开系统颜色面板，选的颜色回写到 Demo（C 的「更多颜色…」、B 的「自定义」用）
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

// MARK: - 四个方案（都是「设置」里的一行）

struct VariantRow: View {
    @ObservedObject var demo: Demo

    var body: some View {
        switch demo.variant {
        case .current: CurrentRow(demo: demo)
        case .swatchRow: SwatchRow(demo: demo)
        case .popoverGrid: PopoverGridRow(demo: demo)
        case .minimalWell: MinimalWellRow(demo: demo)
        }
    }
}

struct CurrentRow: View {
    @ObservedObject var demo: Demo
    var body: some View {
        HStack {
            Text("用户预设颜色 (自定义背景)")
            Spacer()
            ColorPicker("", selection: Binding(get: { Color(nsColor: demo.color) }, set: { demo.color = NSColor($0) }), supportsOpacity: false)
                .labelsHidden()
        }
        .frame(height: 16)
    }
}

struct SwatchRow: View {
    @ObservedObject var demo: Demo
    @State private var hovered: UInt32?

    var body: some View {
        HStack(spacing: 6) {
            Text("用户预设颜色 (自定义背景)")
            Spacer(minLength: 8)
            ForEach(Swatch.all.prefix(8)) { swatch in
                circle(fill: AnyShapeStyle(swatch.color), selected: demo.isSelected(swatch))
                    .help(swatch.name)
                    .onTapGesture { demo.color = swatch.nsColor }
            }
            let custom = !Swatch.all.prefix(8).contains(where: demo.isSelected)
            ZStack {
                circle(fill: AnyShapeStyle(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center)),
                       selected: custom)
                if custom {
                    Circle().fill(Color(nsColor: demo.color)).frame(width: 9, height: 9)
                } else {
                    Image(systemName: "plus").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                }
            }
            .help("自定义…")
            .onTapGesture { ColorPanelBridge.shared.open(for: demo) }
        }
        .frame(height: 22)
    }

    private func circle(fill: AnyShapeStyle, selected: Bool) -> some View {
        ZStack {
            Circle().fill(fill).frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
            if selected { Circle().strokeBorder(Color.accentColor, lineWidth: 2).frame(width: 22, height: 22) }
        }
        .frame(width: 22, height: 22)
        .contentShape(Circle())
    }
}

struct PopoverGridRow: View {
    @ObservedObject var demo: Demo
    @State private var showing = false

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
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 10), count: 4), spacing: 10) {
                        ForEach(Swatch.all) { swatch in
                            ZStack {
                                Circle().fill(swatch.color).frame(width: 24, height: 24)
                                    .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                                if demo.isSelected(swatch) {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(swatch.hex > 0x999999 ? .black : .white)
                                }
                            }
                            .help(swatch.name)
                            .onTapGesture { demo.color = swatch.nsColor; showing = false }
                        }
                    }
                    Divider()
                    Button("更多颜色…") { showing = false; ColorPanelBridge.shared.open(for: demo) }
                        .buttonStyle(.borderless)
                }
                .padding(14)
            }
        }
        .frame(height: 16)
    }
}

struct MinimalWellRow: View {
    @ObservedObject var demo: Demo
    var body: some View {
        HStack {
            Text("用户预设颜色 (自定义背景)")
            Spacer()
            MinimalWell(demo: demo).frame(width: 44, height: 22)
        }
        .frame(height: 22)
    }
}

struct MinimalWell: NSViewRepresentable {
    @ObservedObject var demo: Demo

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell(style: .minimal)
        well.supportsAlpha = false
        well.target = context.coordinator
        well.action = #selector(Coordinator.changed(_:))
        return well
    }

    func updateNSView(_ well: NSColorWell, context: Context) {
        context.coordinator.demo = demo
        if well.color != demo.color { well.color = demo.color }
    }

    func makeCoordinator() -> Coordinator { Coordinator(demo: demo) }

    @MainActor final class Coordinator: NSObject {
        var demo: Demo
        init(demo: Demo) { self.demo = demo }
        @objc func changed(_ sender: NSColorWell) { demo.color = sender.color }
    }
}

// MARK: - 窗口：仿设置页的一组 + 效果预览 + 切换栏

struct PrototypeView: View {
    @ObservedObject var demo: Demo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("录制设置").font(.headline)) {
                VStack(spacing: 10) {
                    HStack { Text("开始录制前倒数 (秒)"); Spacer(); Text("0").monospacedDigit().foregroundStyle(.secondary) }
                        .frame(height: 16)
                    Divider().opacity(0.5)
                    VariantRow(demo: demo)
                }
                .padding(5)
            }

            Text("效果预览：「录制应用程序」时，应用窗口以外的区域就是这个颜色").font(.caption).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: demo.color))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 9, height: 9) }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(white: 0.93))
                    Color.white
                }
                .frame(width: 220, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }
            .frame(height: 180)

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
            Text("当前颜色：\(demo.hex)    （A / D 点开的是系统面板，C 的「更多颜色…」、B 的彩色圆点也会打开它）")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(20)
        .frame(width: 460)
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
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize), styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "PROTOTYPE · 自定义背景色"
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
        print("取色界面原型已启动：底部 ◀ ▶ 或键盘 ← → 切换方案；关掉窗口退出。")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

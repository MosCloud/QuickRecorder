// PROTOTYPE — 一次性代码，不属于 QuickRecorder 的 app target。
//
// 问题：刘海胶囊里的停止按钮怎么做得更好看，同时保持胶囊现在的风格？
// 四个方案显示在刘海正下方的真实位置（和 app 里的胶囊同尺寸、同材质），底部切换栏可以：
//   ◀ ▶（或键盘 ← →）换方案；切换材质；看「暂停中」和「变淡 50%」时的样子。
// A 是现在 app 里的样子；B / C / D 都把红色画在玻璃效果之外（设计里要求的「红色不被玻璃冲淡」）。
//
// 运行：prototypes/stop-button/run.sh          刘海下方 + 切换栏
//       prototypes/stop-button/run.sh gallery  总览：4 个方案 × 3 种材质摆在一起（屏幕上方居中）

import AppKit
import SwiftUI

enum Variant: Int, CaseIterable {
    case current, ring, glassProminent, labeled

    var title: String {
        switch self {
        case .current: "A 现状：红色实心圆"
        case .ring: "B 录制环：圆环 + 红色圆角方块"
        case .glassProminent: "C 玻璃红键：Liquid Glass 强调按钮"
        case .labeled: "D 带字红键：「■ 停止」"
        }
    }
}

enum Material: String, CaseIterable {
    case glass, blur, black
    var title: String { ["glass": "Liquid Glass", "blur": "毛玻璃", "black": "纯黑"][rawValue]! }
}

@MainActor
final class Demo: ObservableObject {
    @Published var variant = Variant.current
    @Published var material = Material.glass
    @Published var paused = false
    @Published var dimmed = false
    @Published var lastClick = "还没点过停止按钮"

    init(variant: Variant = .current, material: Material = .glass) {
        self.variant = variant
        self.material = material
    }
}

/// 总览：每行一个方案，每列一种材质
struct Gallery: View {
    let demos = Variant.allCases.map { v in Material.allCases.map { Demo(variant: v, material: $0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 24) {
                Text("").frame(width: 190)
                ForEach(Material.allCases, id: \.self) { Text($0.title).frame(width: Capsule.size.width) }
            }
            ForEach(Variant.allCases, id: \.self) { v in
                HStack(spacing: 24) {
                    Text(v.title).frame(width: 190, alignment: .leading)
                    ForEach(Material.allCases, id: \.self) { m in Capsule(demo: demos[v.rawValue][m.rawValue == "glass" ? 0 : m.rawValue == "blur" ? 1 : 2]) }
                }
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 2)
        .padding(20)
    }
}

// MARK: - 停止按钮的四个方案

struct StopButton: View {
    let variant: Variant
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        switch variant {
        case .current:
            Button(action: action) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.red))
            }
            .buttonStyle(.plain)

        case .ring:
            Button(action: action) {
                ZStack {
                    Circle().strokeBorder(.primary.opacity(hovering ? 0.9 : 0.55), lineWidth: 2)
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(Color(nsColor: .systemRed))
                        .frame(width: hovering ? 13 : 12, height: hovering ? 13 : 12)
                }
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .animation(.smooth(duration: 0.15), value: hovering)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }

        case .glassProminent:
            Button(action: action) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(Color(nsColor: .systemRed))

        case .labeled:
            Button(action: action) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(.white).frame(width: 9, height: 9)
                    Text("停止").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .systemRed).opacity(hovering ? 1 : 0.92)))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}

// MARK: - 胶囊（和 app 里的 NotchCapsuleView 同尺寸、同材质）

struct Capsule: View {
    @ObservedObject var demo: Demo
    @Environment(\.colorScheme) private var colorScheme
    static let size = CGSize(width: 236, height: 40)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let isBlack = demo.material == .black
        Group {
            if demo.variant == .current {
                // 现状：整排内容放进玻璃里，红色会被玻璃的通透效果冲淡
                switch demo.material {
                case .glass: controls.glassEffect(.regular, in: shape)
                case .blur: controls.background(.regularMaterial, in: shape)
                case .black: controls.background(Color.black, in: shape)
                }
            } else {
                // B / C / D：玻璃只做背景，按钮在玻璃之外，颜色保持原样
                controls.background {
                    switch demo.material {
                    case .glass: Color.clear.glassEffect(.regular, in: shape)
                    case .blur: shape.fill(.regularMaterial)
                    case .black: shape.fill(.black)
                    }
                }
            }
        }
        .environment(\.colorScheme, isBlack ? .dark : colorScheme)
        .opacity(demo.dimmed ? 0.5 : 1)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            StopButton(variant: demo.variant) { demo.lastClick = "点了停止（\(demo.variant.title.prefix(1))）\(Date().formatted(date: .omitted, time: .standard))" }
            Button {} label: {
                Image(systemName: demo.paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .semibold)).frame(width: 28, height: 28)
            }
            Text(demo.paused ? "01:23" : "01:24")
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(demo.paused ? .secondary : .primary)
                .frame(minWidth: 52)
            Divider().frame(height: 18)
            Button {} label: {
                Image(systemName: "camera.fill").font(.system(size: 13, weight: .semibold)).frame(width: 28, height: 28)
            }
        }
        .buttonStyle(.plain)
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

// MARK: - 切换栏（不属于被评估的设计）

struct SwitcherBar: View {
    @ObservedObject var demo: Demo

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                Text(demo.variant.title).frame(width: 300).monospacedDigit()
                Button { step(1) } label: { Image(systemName: "chevron.right") }
            }
            .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 14) {
                Picker("", selection: $demo.material) {
                    ForEach(Material.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                Toggle("暂停中", isOn: $demo.paused)
                Toggle("变淡 50%", isOn: $demo.dimmed)
                Button("退出") { NSApp.terminate(nil) }
            }
            Text(demo.lastClick).font(.caption).foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.85)))
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .padding(8)
        .background(KeyCatcher { demo, key in
            if key == 123 { step(-1) } else if key == 124 { step(1) }
        }.environmentObject(demo))
    }

    private func step(_ by: Int) {
        let all = Variant.allCases
        demo.variant = all[(demo.variant.rawValue + by + all.count) % all.count]
        print("→ \(demo.variant.title) / \(demo.material.title)")
    }
}

/// ← → 切换方案
struct KeyCatcher: NSViewRepresentable {
    let onKey: (Demo, UInt16) -> Void
    @EnvironmentObject var demo: Demo
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { onKey(demo, event.keyCode) }
            return event
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - 入口

@main
@MainActor
final class PrototypeApp: NSObject, NSApplicationDelegate {
    private let demo = Demo()
    private var panels = [NSPanel]()

    static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        let app = NSApplication.shared
        let delegate = PrototypeApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        if CommandLine.arguments.contains("gallery") {
            let gallery = FirstMouseHostingView(rootView: Gallery())
            let size = gallery.fittingSize
            show(Gallery(), frame: NSRect(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 40,
                                          width: size.width, height: size.height), level: .floating, key: true)
            print("总览已显示在屏幕上方；在终端按 Ctrl+C 退出。")
            return
        }
        // 和 app 里一样：胶囊在菜单栏下方 6pt，水平居中（刘海正下方）
        let menuBar = max(screen.frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)
        let size = Capsule.size
        let capsuleFrame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - menuBar - 6 - size.height,
                                  width: size.width, height: size.height)
        show(Capsule(demo: demo), frame: capsuleFrame, level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1))

        let bar = FirstMouseHostingView(rootView: SwitcherBar(demo: demo))
        let barSize = bar.fittingSize
        show(SwitcherBar(demo: demo), frame: NSRect(x: screen.visibleFrame.midX - barSize.width / 2, y: screen.visibleFrame.minY + 30,
                                                     width: barSize.width, height: barSize.height), level: .floating, key: true)
        NSApp.activate()
        print("停止按钮原型已启动：底部切换栏 ◀ ▶ 或键盘 ← → 换方案。")
    }

    private func show<V: View>(_ view: V, frame: NSRect, level: NSWindow.Level, key: Bool = false) {
        let panel = KeyablePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = FirstMouseHostingView(rootView: view)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if key { panel.makeKeyAndOrderFront(nil) } else { panel.orderFrontRegardless() }
        panels.append(panel)
    }
}

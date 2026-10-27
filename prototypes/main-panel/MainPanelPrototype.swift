//
//  MainPanelPrototype.swift
//  PROTOTYPE — throwaway code for #48, not part of the app.
//
//  Question: how should the main panel look with Preferences and Quit as icon buttons, the microphone moved to the
//  right end beside them, and the capsule's three materials (Liquid Glass, frosted, black) behind it?
//  The right end comes in two arrangements: one column of icons (the mic's device in a chevron menu), or two rows
//  (mic and device picker above, ⚙ ⊗ below). Nothing records; every action is only logged in the info window.
//

import AppKit
import AVFoundation
import Combine
import SwiftUI

enum HoverStyle: String, CaseIterable { case original = "原版", soft = "柔和", glide = "滑动", glass = "玻璃" }
enum RightEnd: String, CaseIterable { case column = "第一版", aligned = "对齐一列", grouped = "分组一列" }
extension EnvironmentValues {
    /// The main panel's size, 1 = the original
    @Entry var panelScale: CGFloat = 1
}

enum PanelMaterial: String, CaseIterable { case glass = "Liquid Glass", blur = "毛玻璃", black = "纯黑" }

struct TileSpec {
    let title: String
    let symbol: String
    var symbolSize: CGFloat = 36
    var overlay = ""
    let hotkey: String?
}

// The main panel's tiles, without Preferences and Quit
let tiles: [TileSpec] = [
    .init(title: "录制系统声音", symbol: "waveform", hotkey: "U"),
    .init(title: "录制全屏画面", symbol: "tv.inset.filled", hotkey: "S"),
    .init(title: "录制屏幕区域", symbol: "viewfinder", hotkey: "A"),
    .init(title: "录制应用程序", symbol: "app", symbolSize: 38, overlay: "App", hotkey: nil),
    .init(title: "录制窗口内容", symbol: "macwindow", hotkey: "W"),
    .init(title: "录制移动设备", symbol: "apps.ipad", hotkey: nil),
]

@MainActor
final class Model: ObservableObject {
    static let shared = Model()
    @Published var rightEnd = RightEnd.grouped
    @Published var material = PanelMaterial.glass
    @Published var showQuit = true
    @Published var scale: CGFloat = 0.9
    @Published var hoverStyle = HoverStyle.glide
    /// The tile under the pointer; one highlight for the whole row, so it can glide between tiles
    @Published var hoveredTile: Int?
    var hoverToken = 0
    @Published var recordMic = true
    @Published var micDevice = "default"
    @Published var lastAction = "（还没有操作）"
    let micList = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
        .devices.map(\.localizedName)

    var micSummary: String { recordMic ? (micDevice == "default" ? "系统默认" : micDevice) : "不录制" }

    func did(_ action: String) {
        lastAction = action
        print(action)
    }
}

/// The main panel's quit colour (`dark_my_red`)
let quitRed = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0xEC / 255, green: 0x6A / 255, blue: 0x5D / 255, alpha: 1)
        : NSColor(srgbRed: 0xAA / 255, green: 0x1B / 255, blue: 0x0C / 255, alpha: 1)
})

// MARK: - The main panel

struct MainPanel: View {
    @EnvironmentObject var model: Model
    @Environment(\.colorScheme) private var colorScheme
    var close: () -> Void
    /// The glass is drawn by an AppKit NSGlassEffectView behind this view instead (diagnosis of the dark rim)
    var appKitGlass = false
    @State private var closeHover = false
    @Namespace private var highlight

    var body: some View {
        let k = model.scale
        let shape = RoundedRectangle(cornerRadius: 14 * k, style: .continuous)
        ZStack(alignment: .topLeading) {
            HStack {
                GlassEffectContainer {
                    HStack {
                        ForEach(tiles.indices, id: \.self) { i in
                            if i > 0 { Divider().frame(height: 70 * k) }
                            TileView(index: i, spec: tiles[i], highlight: highlight) { model.did(tiles[i].title) }
                        }
                    }
                }
                Divider().frame(height: 70 * k)
                switch model.rightEnd {
                case .column: column
                case .aligned: aligned
                case .grouped: grouped
                }
            }
            .padding(.vertical, 10 * k)
            .padding(.horizontal, 20 * k)
            Button(action: close) {
                Image(systemName: "x.circle")
                    .font(.system(size: 13 * k, weight: .bold))
                    .opacity(closeHover ? 1 : 0.4)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .onHover { closeHover = $0 }
            .padding([.horizontal, .top], 7 * k)
        }
        .environment(\.colorScheme, model.material == .black ? .dark : colorScheme)
        .background {
            background(shape)
                .contentShape(shape)
                .gesture(WindowDragGesture())
        }
        .allowsWindowActivationEvents(true)
        .environment(\.panelScale, k)
        .fixedSize()
        .onChange(of: model.recordMic) { model.did("麦克风 \(model.micSummary)") }
        .onChange(of: model.micDevice) { model.did("麦克风 \(model.micSummary)") }
    }

    /// The capsule's three materials
    @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
        switch model.material {
        case .glass where appKitGlass: Color.clear
        case .glass: Color.clear.glassEffect(.regular, in: shape)
        case .blur: shape.fill(.regularMaterial).environment(\.controlActiveState, .active)
        case .black: shape.fill(.black)
        }
    }

    /// Round 1: the mic with its device chevron beside it, then ⚙ ⊗
    private var column: some View {
        VStack(spacing: 1) {
            HStack(spacing: 0) {
                MicToggle(isOn: $model.recordMic)
                devicePicker { Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)) }
            }
            .padding(.leading, 12)
            IconButton(symbol: "gearshape", help: "偏好设置") { model.did("偏好设置") }
            if model.showQuit { quitButton }
        }
        .frame(width: 56 * model.scale)
    }

    /// All three on one axis, evenly spaced; the device chevron is a small badge on the mic
    private var aligned: some View {
        VStack(spacing: model.showQuit ? 1 : 12) {
            MicToggle(isOn: $model.recordMic)
                .overlay(alignment: .bottomTrailing) {
                    devicePicker {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(3)
                    }
                    .offset(x: 9, y: 3)
                }
            IconButton(symbol: "gearshape", help: "偏好设置") { model.did("偏好设置") }
            if model.showQuit { quitButton }
        }
        .frame(width: 48 * model.scale)
    }

    /// The mic over its device's name, a short divider, then ⚙ ⊗ side by side
    private var grouped: some View {
        VStack(spacing: 4 * model.scale) {
            MicToggle(isOn: $model.recordMic)
            devicePicker {
                HStack(spacing: 2) {
                    Text(model.micDevice == "default" ? "系统默认" : model.micDevice)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
                }
                .font(.system(size: max(9, 10 * model.scale)))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 70 * model.scale)
            }
            Divider().frame(width: 40).padding(.vertical, 1)
            HStack(spacing: 2) {
                IconButton(symbol: "gearshape", help: "偏好设置") { model.did("偏好设置") }
                if model.showQuit { quitButton }
            }
        }
        .frame(width: 76 * model.scale)
    }

    private var quitButton: some View {
        IconButton(symbol: "xmark.circle", help: "退出程序", hoverTint: quitRed) { model.did("退出程序") }
    }

    /// The microphone's device, in a menu that `label` opens; drawn by hand because SwiftUI's Menu restyles its label
    private func devicePicker(@ViewBuilder label: () -> some View) -> some View {
        Button {
            DeviceMenu.shared.show(devices: model.micList, selected: model.micDevice) { model.micDevice = $0 }
        } label: {
            label().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.recordMic)
        .help("麦克风设备：\(model.micDevice == "default" ? "系统默认" : model.micDevice)")
    }
}

/// Pops up the microphone list under the pointer, with a checkmark on the chosen one
@MainActor
final class DeviceMenu: NSObject {
    static let shared = DeviceMenu()
    private var pick: ((String) -> Void)?

    func show(devices: [String], selected: String, pick: @escaping (String) -> Void) {
        self.pick = pick
        let menu = NSMenu()
        for (title, tag) in [("系统默认", "default")] + devices.map({ ($0, $0) }) {
            let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            item.state = tag == selected ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func choose(_ sender: NSMenuItem) { pick?(sender.representedObject as! String) }
}

/// The main panel's `SelectorView`, with the hover highlight chosen in the info window
struct TileView: View {
    @Environment(\.panelScale) private var k
    @EnvironmentObject var model: Model
    let index: Int
    let spec: TileSpec
    var highlight: Namespace.ID
    let action: () -> Void

    var body: some View {
        let on = model.hoveredTile == index
        Button(action: action) {
            VStack(spacing: 6 * k) {
                Text(spec.title).opacity(0.95).font(.system(size: 12 * k))
                ZStack {
                    Image(systemName: spec.symbol).opacity(0.95).font(.system(size: spec.symbolSize * k)).frame(height: 40 * k)
                    Text(spec.overlay).fontWeight(.bold).opacity(0.95).font(.system(size: 11 * k))
                }
            }
            .frame(width: 110 * k, height: 80 * k)
            .background { highlightView(on) }
            // Glass goes on the tile itself, so the title and icon sit on top of it rather than under it
            .glassEffect(model.hoverStyle == .glass && on ? .regular.interactive() : .identity,
                         in: RoundedRectangle(cornerRadius: 10 * k, style: .continuous).inset(by: 3 * k))
            .glassEffectID(on ? "highlight" : "tile \(index)", in: highlight)
            .contentShape(Rectangle())
        }
        .buttonStyle(TilePress(pressable: model.hoverStyle != .original))
        .onHover { inside in
            let animation: Animation? = model.hoverStyle == .glide || model.hoverStyle == .glass ? .snappy(duration: 0.22) : nil
            if inside {
                model.hoverToken += 1
                withAnimation(animation) { model.hoveredTile = index }
            } else if model.hoveredTile == index {
                // Crossing the gap to the next tile shouldn't blink the highlight off and on
                let token = model.hoverToken
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    if model.hoverToken == token { withAnimation(animation ?? .easeOut(duration: 0.15)) { model.hoveredTile = nil } }
                }
            }
        }
        .help(spec.hotkey.map { "⌃⌥⌘\($0)" } ?? "")
    }

    @ViewBuilder private func highlightView(_ on: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10 * k, style: .continuous)
        switch model.hoverStyle {
        case .original:
            // As now: the whole cell, 20% grey, no fade
            Rectangle().fill(.primary.opacity(on ? 0.2 : 0.0001)).cornerRadius(8)
        case .soft:
            shape.fill(.primary.opacity(on ? 0.1 : 0)).padding(3 * k).animation(.easeOut(duration: 0.15), value: on)
        case .glide:
            if on { shape.fill(.primary.opacity(0.1)).padding(3 * k).matchedGeometryEffect(id: "highlight", in: highlight) }
        case .glass:
            EmptyView()
        }
    }
}

/// Pressing a tile shrinks it a little, until released
struct TilePress: ButtonStyle {
    var pressable: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(pressable && configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// From the app (#47)
struct MicToggle: View {
    @Environment(\.panelScale) private var k
    @Binding var isOn: Bool
    @State private var hovering = false
    @State private var bounces = 0
    private let speed = 1.5

    var body: some View {
        Button {
            isOn.toggle()
            if isOn { bounces += 1 }
        } label: {
            Image(systemName: isOn ? "mic.fill" : "mic.slash")
                .font(.system(size: 14 * k, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace, options: .speed(speed)))
                .symbolEffect(.bounce, options: .speed(speed), value: bounces)
                .frame(width: 26 * k, height: 26 * k)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
                .animation(.smooth(duration: 0.2 / speed), value: isOn)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("录制麦克风")
    }
}

/// From the app (#47)
struct IconButton: View {
    @Environment(\.panelScale) private var k
    let symbol: String
    let help: String
    var hoverTint: Color = .primary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15 * k))
                .foregroundStyle(hovering ? AnyShapeStyle(hoverTint) : AnyShapeStyle(.secondary))
                .frame(width: 26 * k, height: 26 * k)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// A stand-in for what is behind the panel: a light page with text lines, or a dark wallpaper
struct TestBackdrop: View {
    let light: Bool

    var body: some View {
        ZStack {
            if light {
                Color.white
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(0..<12, id: \.self) { i in
                        Capsule().fill(Color.gray.opacity(0.35)).frame(width: CGFloat(300 + (i * 97) % 500), height: 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
                Circle().fill(Color.orange.opacity(0.8)).frame(width: 90).offset(x: 260, y: -30)
            } else {
                LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.2), Color(red: 0.2, green: 0.15, blue: 0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.cyan.opacity(0.5)).frame(width: 120).offset(x: -300, y: 20)
            }
        }
    }
}

// MARK: - Info window

struct InfoView: View {
    @EnvironmentObject var model: Model
    let showPanel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主面板原型（#48）").font(.headline)
            Text("屏幕中间偏上的就是新的主面板：设置和退出改成右端的图标，麦克风也移到右端，背景可以换三种材质。Liquid Glass 的黑边已修复（关掉了窗口阴影）。这个原型不会真的录制，只记录你点了什么；点 ⊗ 也不会退出。主面板现在可以按住空白处拖动。想和现在的主面板对比，可以打开 QuickRecorder 后按 ⌃⌥⌘R。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("右端排法").foregroundStyle(.secondary)
                    Picker("", selection: $model.rightEnd) {
                        ForEach(RightEnd.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                GridRow {
                    Text("尺寸").foregroundStyle(.secondary)
                    Picker("", selection: $model.scale) {
                        Text("100%（原版）").tag(CGFloat(1))
                        Text("90%").tag(CGFloat(0.9))
                        Text("80%").tag(CGFloat(0.8))
                    }
                    .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                GridRow {
                    Text("悬停效果").foregroundStyle(.secondary)
                    Picker("", selection: $model.hoverStyle) {
                        ForEach(HoverStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                GridRow {
                    Text("背景材质").foregroundStyle(.secondary)
                    Picker("", selection: $model.material) {
                        ForEach(PanelMaterial.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                GridRow {
                    Text("退出按钮").foregroundStyle(.secondary)
                    Toggle("显示（只在不显示 Dock 和菜单栏图标时出现）", isOn: $model.showQuit)
                }
                GridRow { Text("上次操作").foregroundStyle(.secondary); Text(model.lastAction) }
                GridRow { Text("麦克风").foregroundStyle(.secondary); Text(model.micSummary) }
            }
            .font(.callout)
            HStack {
                Button("显示主面板", action: showPanel)
                Spacer()
                Button("退出原型") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 480)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var host: NSHostingView<AnyView>!
    var window: NSWindow!
    var changes: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--diagnose"), args.count > i + 3 {
            diagnose(variant: Int(args[i + 1]) ?? 0, backdrop: args[i + 2], output: args[i + 3])
            return
        }
        // Like the app's main panel: borderless, floating, moved by its background
        panel = NSPanel(contentRect: .zero, styleMask: [.fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        host = NSHostingView(rootView: AnyView(MainPanel { [unowned self] in panel.orderOut(nil) }.environmentObject(Model.shared)))
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces]
        fit(recenter: true)
        panel.orderFront(nil)
        // Keep it centered on its row as the right end changes width
        changes = Model.shared.objectWillChange.sink { [unowned self] _ in DispatchQueue.main.async { self.fit(recenter: false) } }

        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "主面板原型"
        window.contentViewController = NSHostingController(rootView: InfoView { [unowned self] in
            fit(recenter: true)
            panel.orderFront(nil)
        }.environmentObject(Model.shared))
        window.isReleasedWhenClosed = false
        if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 240, y: screen.visibleFrame.minY + 60))
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Shows the Liquid Glass panel one way over a test backdrop, captures that region, and quits.
    /// 0 as now · 1 no window shadow · 2 a 24-point margin · 3 both · 4 both, with AppKit's NSGlassEffectView
    private func diagnose(variant: Int, backdrop: String, output: String) {
        if variant >= 40 {
            Model.shared.scale = 0.9
            Model.shared.rightEnd = .grouped
            Model.shared.hoverStyle = HoverStyle.allCases[(variant - 40) % 4]
            Model.shared.material = PanelMaterial.allCases[(variant - 40) / 4]
            Model.shared.hoveredTile = 2
        } else if variant >= 10 {
            // 10 + right end × 3 + material: the fixed panel as it now is
            Model.shared.rightEnd = RightEnd.allCases[((variant - 10) / 3) % 3]
            Model.shared.scale = [1, 0.9, 0.8][(variant - 10) / 9]
            Model.shared.material = PanelMaterial.allCases[(variant - 10) % 3]
        } else {
            Model.shared.material = .glass
        }
        let shadow = variant >= 10 ? Model.shared.material != .glass : variant == 0 || variant == 2
        let margin: CGFloat = variant >= 2 && variant < 10 ? 24 : 0
        let appKit = variant == 4
        let host = NSHostingView(rootView: MainPanel(close: {}, appKitGlass: appKit).environmentObject(Model.shared))
        let size = host.fittingSize
        let container = NSView(frame: NSRect(x: 0, y: 0, width: size.width + 2 * margin, height: size.height + 2 * margin))
        let inner = NSRect(x: margin, y: margin, width: size.width, height: size.height)
        if appKit {
            let glass = NSGlassEffectView(frame: inner)
            glass.cornerRadius = 14
            host.frame = glass.bounds
            glass.contentView = host
            container.addSubview(glass)
        } else {
            host.frame = inner
            container.addSubview(host)
        }
        guard let screen = NSScreen.main else { return }
        let frame = NSRect(x: screen.frame.midX - container.frame.width / 2, y: screen.frame.midY - container.frame.height / 2,
                           width: container.frame.width, height: container.frame.height)
        panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = container
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = shadow
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)

        let around = frame.insetBy(dx: -40, dy: -40)
        let back = NSWindow(contentRect: around, styleMask: [.borderless], backing: .buffered, defer: false)
        back.level = .floating
        back.contentView = NSHostingView(rootView: TestBackdrop(light: backdrop == "light"))
        back.orderFrontRegardless()
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // screencapture's -R counts from the top left of the main display
            let top = NSScreen.screens[0].frame.maxY - around.maxY
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-R", "\(Int(around.minX)),\(Int(top)),\(Int(around.width)),\(Int(around.height))", output]
            try? capture.run()
            capture.waitUntilExit()
            NSApp.terminate(nil)
        }
    }

    private func fit(recenter: Bool) {
        // The window shadow outlines a borderless window in a dark line, which shows as a black rim around Liquid Glass
        panel.hasShadow = Model.shared.material != .glass
        let size = host.fittingSize
        guard let screen = NSScreen.main else { return }
        let midX = recenter ? screen.frame.midX : panel.frame.midX
        let midY = recenter ? screen.frame.midY + 150 : panel.frame.midY
        panel.setFrame(NSRect(x: midX - size.width / 2, y: midY - size.height / 2, width: size.width, height: size.height), display: true)
    }
}

@main
struct MainPanelPrototype {
    @MainActor static let delegate = AppDelegate()

    @MainActor static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)   // the action log reaches a file line by line
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

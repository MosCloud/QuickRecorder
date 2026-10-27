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

enum RightEnd: String, CaseIterable { case column = "一列", rows = "两行" }
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
    @Published var rightEnd = RightEnd.column
    @Published var material = PanelMaterial.glass
    @Published var showQuit = true
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
    @State private var closeHover = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack(alignment: .topLeading) {
            HStack {
                ForEach(tiles.indices, id: \.self) { i in
                    if i > 0 { Divider().frame(height: 70) }
                    TileView(spec: tiles[i]) { model.did(tiles[i].title) }
                }
                Divider().frame(height: 70)
                switch model.rightEnd {
                case .column: column
                case .rows: rows
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            Button(action: close) {
                Image(systemName: "x.circle")
                    .font(.system(size: 13, weight: .bold))
                    .opacity(closeHover ? 1 : 0.4)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .onHover { closeHover = $0 }
            .padding([.horizontal, .top], 7)
        }
        .environment(\.colorScheme, model.material == .black ? .dark : colorScheme)
        .background { background(shape) }
        .fixedSize()
        .onChange(of: model.recordMic) { model.did("麦克风 \(model.micSummary)") }
        .onChange(of: model.micDevice) { model.did("麦克风 \(model.micSummary)") }
    }

    /// The capsule's three materials
    @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
        switch model.material {
        case .glass: Color.clear.glassEffect(.regular, in: shape)
        case .blur: shape.fill(.regularMaterial).environment(\.controlActiveState, .active)
        case .black: shape.fill(.black)
        }
    }

    /// One column of icons; the mic's device sits in the chevron beside it
    private var column: some View {
        VStack(spacing: 1) {
            HStack(spacing: 0) {
                MicToggle(isOn: $model.recordMic)
                Menu {
                    Picker("", selection: $model.micDevice) {
                        Text("系统默认").tag("default")
                        ForEach(model.micList, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(!model.recordMic)
                .help("麦克风设备：\(model.micDevice == "default" ? "系统默认" : model.micDevice)")
            }
            .padding(.leading, 12)
            IconButton(symbol: "gearshape", help: "偏好设置") { model.did("偏好设置") }
            if model.showQuit {
                IconButton(symbol: "xmark.circle", help: "退出程序", hoverTint: quitRed) { model.did("退出程序") }
            }
        }
        .frame(width: 56)
    }

    /// Two rows: the mic and its device picker, then ⚙ ⊗
    private var rows: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 4) {
                MicToggle(isOn: $model.recordMic)
                Picker("", selection: $model.micDevice) {
                    Text("系统默认").tag("default")
                    ForEach(model.micList, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                .disabled(!model.recordMic)
            }
            HStack(spacing: 4) {
                IconButton(symbol: "gearshape", help: "偏好设置") { model.did("偏好设置") }
                if model.showQuit {
                    IconButton(symbol: "xmark.circle", help: "退出程序", hoverTint: quitRed) { model.did("退出程序") }
                }
            }
        }
        .padding(.leading, 4)
    }
}

/// The main panel's `SelectorView`
struct TileView: View {
    let spec: TileSpec
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(spec.title).opacity(0.95).font(.system(size: 12))
                ZStack {
                    Image(systemName: spec.symbol).opacity(0.95).font(.system(size: spec.symbolSize)).frame(height: 40)
                    Text(spec.overlay).fontWeight(.bold).opacity(0.95).font(.system(size: 11))
                }
            }
            .frame(width: 110, height: 80)
            .background(.primary.opacity(hovering ? 0.2 : 0.0001))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(spec.hotkey.map { "⌃⌥⌘\($0)" } ?? "")
    }
}

/// From the app (#47)
struct MicToggle: View {
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace, options: .speed(speed)))
                .symbolEffect(.bounce, options: .speed(speed), value: bounces)
                .frame(width: 26, height: 26)
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
    let symbol: String
    let help: String
    var hoverTint: Color = .primary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(hovering ? AnyShapeStyle(hoverTint) : AnyShapeStyle(.secondary))
                .frame(width: 26, height: 26)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Info window

struct InfoView: View {
    @EnvironmentObject var model: Model
    let showPanel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主面板原型（#48）").font(.headline)
            Text("屏幕中间偏上的就是新的主面板：设置和退出改成右端的图标，麦克风也移到右端，背景可以换三种材质。这个原型不会真的录制，只记录你点了什么；点 ⊗ 也不会退出。想和现在的主面板对比，可以打开 QuickRecorder 后按 ⌃⌥⌘R。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("右端排列").foregroundStyle(.secondary)
                    Picker("", selection: $model.rightEnd) {
                        ForEach(RightEnd.allCases, id: \.self) { Text($0.rawValue).tag($0) }
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

    private func fit(recenter: Bool) {
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
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

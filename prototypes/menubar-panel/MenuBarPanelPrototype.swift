//
//  MenuBarPanelPrototype.swift
//  PROTOTYPE — throwaway code for #46, not part of the app.
//
//  Question: while idle, what should the menu bar item open? The current popover reuses the main panel's
//  110×80 tiles in a 2×4 grid (≈470×190) and orders them differently from the main panel.
//  A: a native NSMenu, like the recording menu, with the hotkeys beside each item.
//  B: a compact, Control Center–style panel about 300 wide.
//  Both follow the main panel's order: system audio (with the microphone), screen, area, app, window, device, settings, quit.
//  Nothing here records; every action is only logged in the info window.
//

import AppKit
import AVFoundation
import SwiftUI

struct RecordAction: Identifiable {
    let title: String
    let symbol: String
    let hotkey: String?   // the letter after ⌃⌥⌘, from #42's defaults
    var id: String { title }
}

// The main panel's order
let recordActions: [RecordAction] = [
    .init(title: "录制系统声音", symbol: "waveform", hotkey: "u"),
    .init(title: "录制全屏画面", symbol: "tv.inset.filled", hotkey: "s"),
    .init(title: "录制屏幕区域", symbol: "viewfinder", hotkey: "a"),
    .init(title: "录制应用程序", symbol: "macwindow.on.rectangle", hotkey: nil),
    .init(title: "录制窗口内容", symbol: "macwindow", hotkey: "w"),
]

@MainActor
final class Model: ObservableObject {
    static let shared = Model()
    @Published var lastAction = "（还没有操作）"
    @Published var recordMic = true
    @Published var micDevice = "default"
    @Published var mute = false
    @Published var preset = "高画质"
    @Published var showDevices = false
    let micList = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
        .devices.map(\.localizedName)
    let devices = ["iPhone（示例设备）"]
    let presets = ["低画质", "中画质", "高画质"]

    var micSummary: String { recordMic ? (micDevice == "default" ? "系统默认" : micDevice) : "不录制" }

    func did(_ action: String, in variant: String) {
        lastAction = "\(variant) → \(action)"
        print(lastAction)
    }
}

// MARK: - A: native menu

@MainActor
final class MenuVariant: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    private var model: Model { .shared }

    override init() {
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "dot.circle.and.hand.point.up.left.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
            button.title = "A"
            button.imagePosition = .imageLeading
        }
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(actionItem(recordActions[0]))
        menu.addItem(microphoneItem())
        menu.addItem(.separator())
        for action in recordActions.dropFirst() { menu.addItem(actionItem(action)) }
        menu.addItem(deviceItem())
        menu.addItem(.separator())
        menu.addItem(plainItem("偏好设置…", "gearshape", key: ",", #selector(settings)))
        menu.addItem(plainItem("退出程序", "power", key: "q", #selector(quit)))
    }

    private func actionItem(_ action: RecordAction) -> NSMenuItem {
        let item = plainItem(action.title, action.symbol, key: nil, #selector(record(_:)))
        if let key = action.hotkey {
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = [.control, .option, .command]
        }
        return item
    }

    private func microphoneItem() -> NSMenuItem {
        let item = NSMenuItem(title: "麦克风：\(model.micSummary)", action: nil, keyEquivalent: "")
        item.image = symbol(model.recordMic ? "mic" : "mic.slash")
        let sub = NSMenu()
        sub.autoenablesItems = false
        let off = plainItem("不录制", nil, key: nil, #selector(pickMic(_:)))
        off.representedObject = ""
        off.state = model.recordMic ? .off : .on
        sub.addItem(off)
        sub.addItem(.separator())
        for (name, tag) in [("系统默认", "default")] + model.micList.map({ ($0, $0) }) {
            let mic = plainItem(name, nil, key: nil, #selector(pickMic(_:)))
            mic.representedObject = tag
            mic.state = model.recordMic && model.micDevice == tag ? .on : .off
            sub.addItem(mic)
        }
        item.submenu = sub
        return item
    }

    private func deviceItem() -> NSMenuItem {
        let item = NSMenuItem(title: "录制移动设备", action: nil, keyEquivalent: "")
        item.image = symbol("apps.ipad")
        let sub = NSMenu()
        sub.autoenablesItems = false
        for device in model.devices {
            let d = plainItem(device, "apple.logo", key: nil, #selector(recordDevice(_:)))
            d.representedObject = device
            sub.addItem(d)
        }
        sub.addItem(.separator())
        let mute = plainItem("静音", nil, key: nil, #selector(toggleMute))
        mute.state = model.mute ? .on : .off
        mute.toolTip = "如需通话时录屏请启用\"静音\""
        sub.addItem(mute)
        sub.addItem(.sectionHeader(title: "预设"))
        for preset in model.presets {
            let p = plainItem(preset, nil, key: nil, #selector(pickPreset(_:)))
            p.representedObject = preset
            p.state = model.preset == preset ? .on : .off
            sub.addItem(p)
        }
        item.submenu = sub
        return item
    }

    private func plainItem(_ title: String, _ symbolName: String?, key: String?, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key ?? "")
        item.target = self
        if let symbolName { item.image = symbol(symbolName) }
        return item
    }

    private func symbol(_ name: String) -> NSImage? { NSImage(systemSymbolName: name, accessibilityDescription: nil) }

    @objc private func record(_ sender: NSMenuItem) { model.did(sender.title, in: "A") }
    @objc private func recordDevice(_ sender: NSMenuItem) { model.did("录制 \(sender.title)（静音：\(model.mute ? "开" : "关")，\(model.preset)）", in: "A") }
    @objc private func toggleMute() { model.mute.toggle(); model.did("静音 \(model.mute ? "开" : "关")", in: "A") }
    @objc private func pickPreset(_ sender: NSMenuItem) { model.preset = sender.representedObject as! String; model.did("预设 \(model.preset)", in: "A") }
    @objc private func settings() { model.did("偏好设置", in: "A") }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func pickMic(_ sender: NSMenuItem) {
        let tag = sender.representedObject as! String
        model.recordMic = !tag.isEmpty
        if !tag.isEmpty { model.micDevice = tag }
        model.did("麦克风 \(model.micSummary)", in: "A")
    }
}

// MARK: - B: compact panel

@MainActor
final class PanelVariant: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()

    override init() {
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "dot.circle.and.hand.point.up.left.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
            button.title = "B"
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggle)
        }
        popover.behavior = .transient
        let host = NSHostingController(rootView: CompactPanel { [weak self] in self?.popover.performClose(nil) }.environmentObject(Model.shared))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        show(relativeTo: button.bounds, of: button, edge: .minY)
    }

    func show(relativeTo rect: NSRect, of view: NSView, edge: NSRectEdge) {
        if popover.isShown { popover.performClose(nil); return }
        popover.show(relativeTo: rect, of: view, preferredEdge: edge)
    }
}

struct CompactPanel: View {
    @EnvironmentObject var model: Model
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(88), spacing: 8), count: 3), spacing: 8) {
                ForEach(recordActions) { action in
                    Tile(title: action.title, symbol: action.symbol, hotkey: action.hotkey) {
                        model.did(action.title, in: "B")
                        close()
                    }
                }
                Tile(title: "录制移动设备", symbol: "apps.ipad", hotkey: nil, isOn: model.showDevices) {
                    withAnimation(.smooth(duration: 0.2)) { model.showDevices.toggle() }
                }
            }
            if model.showDevices { devices }
            Divider()
            HStack(spacing: 8) {
                Image(systemName: model.recordMic ? "mic.fill" : "mic.slash")
                    .frame(width: 18)
                    .foregroundStyle(model.recordMic ? .primary : .secondary)
                Text("录制麦克风")
                Spacer()
                Picker("", selection: $model.micDevice) {
                    Text("系统默认").tag("default")
                    ForEach(model.micList, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                .disabled(!model.recordMic)
                Toggle("", isOn: $model.recordMic)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .font(.system(size: 12))
            Divider()
            HStack {
                Button { model.did("偏好设置", in: "B"); close() } label: { Label("偏好设置…", systemImage: "gearshape") }
                Spacer()
                Button { NSApp.terminate(nil) } label: { Label("退出程序", systemImage: "power") }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
        }
        .padding(12)
        .frame(width: 304)
        .onChange(of: model.recordMic) { model.did("麦克风 \(model.micSummary)", in: "B") }
        .onChange(of: model.micDevice) { model.did("麦克风 \(model.micSummary)", in: "B") }
    }

    private var devices: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.devices, id: \.self) { device in
                Button {
                    model.did("录制 \(device)（静音：\(model.mute ? "开" : "关")，\(model.preset)）", in: "B")
                    close()
                } label: {
                    Label(device, systemImage: "apple.logo").frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
            HStack {
                Toggle("静音", isOn: $model.mute).toggleStyle(.checkbox)
                    .help("如需通话时录屏请启用\"静音\"")
                Spacer()
                Picker("预设", selection: $model.preset) {
                    ForEach(model.presets, id: \.self) { Text($0).tag($0) }
                }
                .fixedSize()
            }
            .controlSize(.small)
        }
        .font(.system(size: 12))
        .padding(10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct Tile: View {
    let title: String
    let symbol: String
    let hotkey: String?
    var isOn = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 20))
                    .frame(height: 24)
                Text(title).font(.system(size: 11))
                    .lineLimit(1)
            }
            .frame(width: 88, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.quaternary.opacity(hovering ? 1 : 0.6)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(hotkey.map { "⌃⌥⌘\($0.uppercased())" } ?? "")
    }
}

// MARK: - Info window

struct InfoView: View {
    @EnvironmentObject var model: Model
    let openA: () -> Void
    let openB: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("菜单栏弹窗原型（#46）").font(.headline)
            Text("菜单栏里多了两个图标：「◉ A」是原生菜单，「◉ B」是紧凑面板，都按主面板的顺序排列。如果图标被刘海或菜单栏管理工具挡住，就用下面的按钮在这里打开。这个原型不会真的录制，只记录你点了什么。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow { Text("上次操作").foregroundStyle(.secondary); Text(model.lastAction) }
                GridRow { Text("麦克风").foregroundStyle(.secondary); Text(model.micSummary) }
                GridRow { Text("移动设备").foregroundStyle(.secondary); Text("静音\(model.mute ? "开" : "关")，\(model.preset)") }
            }
            .font(.callout)
            HStack {
                Button("在这里打开 A", action: openA)
                Button("在这里打开 B", action: openB)
                Spacer()
                Button("退出原型") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuVariant: MenuVariant!
    var panelVariant: PanelVariant!
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuVariant = MenuVariant()
        panelVariant = PanelVariant()
        let info = InfoView(openA: { [unowned self] in openA() }, openB: { [unowned self] in openB() })
            .environmentObject(Model.shared)
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "菜单栏弹窗原型"
        window.contentViewController = NSHostingController(rootView: info)
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func openA() {
        guard let view = window.contentView else { return }
        menuVariant.menu.popUp(positioning: nil, at: NSPoint(x: 16, y: view.isFlipped ? view.bounds.height - 8 : 8), in: view)
    }

    private func openB() {
        guard let view = window.contentView else { return }
        panelVariant.show(relativeTo: NSRect(x: view.bounds.midX, y: 0, width: 1, height: view.bounds.height), of: view, edge: .maxX)
    }
}

@main
struct MenuBarPanelPrototype {
    @MainActor static let delegate = AppDelegate()

    @MainActor static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

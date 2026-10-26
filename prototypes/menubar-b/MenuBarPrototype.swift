// PROTOTYPE — 一次性代码，用完即弃，不属于 QuickRecorder 的 app target。
//
// 已定结论：
//   第 1 轮：选样式 3 = 菜单栏「● 计时」+ 原生菜单，再加一个浮动胶囊。
//   第 2 轮：两者做成独立开关、至少保留一个；原生菜单项和胶囊按钮在 macOS 27 上点击都生效。
//   第 2 轮后：胶囊先固定在刘海下方，不支持拖动（以后的版本再细化）。
//   第 3 轮：「从刘海弹出 / 收回刘海」动效满意，参数用系统 .bouncy（0.5s / 0.3），收回用 .smooth。
// 第 4 轮要回答的问题：
//   1. 胶囊的圆角参考刘海：胶囊 / 刘海圆角（圆角矩形，半径可调）/ 刘海延伸（顶部贴住刘海，带内凹过渡）
//   2. 去掉黑色描边：那圈深色边是系统 Liquid Glass 自带的边缘效果，没有参数能关，只能换材质比较：
//      Liquid Glass / 毛玻璃（无描边）/ 纯黑（和刘海同色，无描边）
// 录制是假的：计时器在走，所有动作只记录到配置条和终端里。
//
// 运行：prototypes/menubar-b/run.sh [shape=pill|notchRounded|notchExtended] [material=glass|blur|black]

import AppKit
import SwiftUI

// MARK: - 配置（模拟设置页）+ 假录制状态

enum CapsuleShapeStyle: String, CaseIterable {
    case pill, notchRounded, notchExtended

    var title: String {
        switch self {
        case .pill: "胶囊"
        case .notchRounded: "刘海圆角"
        case .notchExtended: "刘海延伸"
        }
    }
}

enum CapsuleMaterial: String, CaseIterable {
    case glass, blur, black

    var title: String {
        switch self {
        case .glass: "Liquid Glass"
        case .blur: "毛玻璃"
        case .black: "纯黑"
        }
    }
}

@MainActor
final class DemoSettings: ObservableObject {
    @Published var showMenuBarItem = true
    @Published var showCapsule = true
    @Published var countdownOn = false
    @Published var simulateNoNotch = false
    @Published var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    @Published var emergeDuration = 0.5
    @Published var bounce = 0.3
    @Published var shape = CapsuleShapeStyle.notchRounded
    @Published var material = CapsuleMaterial.glass
    @Published var cornerRadius = 10.0

    var configText: String {
        switch (showMenuBarItem, showCapsule) {
        case (true, true): "菜单栏 + 胶囊"
        case (true, false): "只有菜单栏"
        case (false, true): "只有胶囊"
        case (false, false): "都关（不允许）"
        }
    }

    var motionText: String {
        reduceMotion ? "减弱动态效果（淡入淡出）"
            : String(format: "spring(duration: %.2f, bounce: %.2f)", emergeDuration, bounce)
    }

    var lookText: String {
        "\(shape.title) + \(material.title)" + (shape == .pill ? "" : String(format: "，圆角 %.0f", cornerRadius))
    }
}

@MainActor
final class FakeRecording: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var isMagnifierOn = false
    @Published private(set) var lastEvent = "还没有收到点击"
    @Published private(set) var tickCount = 0 // 只用来驱动界面刷新

    private var startedAt = Date()
    private var pausedAt: Date?
    private var stoppedAt: Date?
    private var pausedTotal: TimeInterval = 0

    // 只用一个时钟（Date()）算时长，避免第 2 轮里暂停/继续时计时往回跳
    var elapsedText: String {
        let end = pausedAt ?? stoppedAt ?? Date()
        let seconds = max(0, Int(end.timeIntervalSince(startedAt) - pausedTotal))
        let h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    var stateText: String { !isRecording ? "未在录制" : (isPaused ? "已暂停" : "录制中") }

    func tick() { tickCount &+= 1 }

    func log(_ action: String, from source: String) {
        lastEvent = "\(action)（来自\(source)）"
        print("✅ 收到：\(lastEvent)  |  状态：\(stateText) \(elapsedText)")
    }

    func start() {
        startedAt = Date()
        pausedAt = nil
        stoppedAt = nil
        pausedTotal = 0
        isPaused = false
        isRecording = true
    }

    func togglePause() {
        if let pausedAt {
            pausedTotal += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
        } else {
            pausedAt = Date()
        }
        isPaused = pausedAt != nil
    }

    func stop() {
        stoppedAt = pausedAt ?? Date()
        pausedAt = nil
        isPaused = false
        isRecording = false
    }

    func toggleMagnifier() { isMagnifierOn.toggle() }
}

struct DemoActions {
    let stop: @MainActor (String) -> Void
    let pause: @MainActor (String) -> Void
    let camera: @MainActor (String) -> Void
}

// MARK: - 菜单栏（第 2 轮已验证，原样保留）

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let rec: FakeRecording
    private let settings: DemoSettings
    private let actions: DemoActions
    private var timerItem: NSStatusItem?
    private let menu = NSMenu()
    private let headerItem = NSMenuItem()
    private var pauseItem: NSMenuItem!
    private var magnifierItem: NSMenuItem!
    private var isMenuOpen = false
    private var shownPaused: Bool?

    var button: NSStatusBarButton? { timerItem?.button }

    init(rec: FakeRecording, settings: DemoSettings, actions: DemoActions) {
        self.rec = rec
        self.settings = settings
        self.actions = actions
        super.init()
        buildMenu()
    }

    /// 根据「是否在录制」和「菜单栏开关」决定状态栏项在不在
    func sync() {
        let wanted = rec.isRecording && settings.showMenuBarItem
        if wanted, timerItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            item.button?.imagePosition = .imageLeading
            item.menu = menu
            timerItem = item
            shownPaused = nil
        } else if !wanted, let item = timerItem {
            NSStatusBar.system.removeStatusItem(item)
            timerItem = nil
        }
        refresh()
    }

    func refresh() {
        timerItem?.button?.title = " " + rec.elapsedText
        headerItem.title = "\(rec.stateText) · \(rec.elapsedText)"
        // 菜单打开期间只更新文字，不动图标和其他菜单项，避免干扰菜单的点击处理
        guard !isMenuOpen, shownPaused != rec.isPaused else { return }
        shownPaused = rec.isPaused
        timerItem?.button?.image = rec.isPaused ? symbol("pause.fill", label: "已暂停") : redDot()
        pauseItem.title = rec.isPaused ? "继续录制" : "暂停录制"
        pauseItem.image = symbol(rec.isPaused ? "play.circle" : "pause.circle", label: pauseItem.title)
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())
        menu.addItem(item("停止录制", "stop.circle", key: "s", #selector(stopFromMenu)))
        pauseItem = item("暂停录制", "pause.circle", key: "p", #selector(pauseFromMenu))
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(item("摄像头…", "camera", key: "", #selector(cameraFromMenu)))
        menu.addItem(item("保存当前帧", "camera.viewfinder", key: "f", #selector(saveFrameFromMenu)))
        magnifierItem = item("屏幕放大镜", "plus.magnifyingglass", key: "m", #selector(magnifierFromMenu))
        menu.addItem(magnifierItem)
    }

    // 快捷键在 demo 里只是显示用；真实 app 会显示用户在设置里录的全局快捷键
    private func item(_ title: String, _ symbolName: String, key: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = [.control, .option]
        item.image = symbol(symbolName, label: title)
        item.target = self
        return item
    }

    private func symbol(_ name: String, label: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        image?.isTemplate = true
        return image
    }

    private func redDot() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .regular)
            .applying(.init(paletteColors: [.systemRed]))
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "录制中")?
            .withSymbolConfiguration(config)
        image?.isTemplate = false
        return image
    }

    func menuWillOpen(_ menu: NSMenu) {
        magnifierItem.state = rec.isMagnifierOn ? .on : .off
        isMenuOpen = true
        rec.log("打开菜单", from: "菜单栏计时")
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        refresh()
    }

    @objc private func stopFromMenu() { actions.stop("菜单") }
    @objc private func pauseFromMenu() { actions.pause("菜单") }
    @objc private func cameraFromMenu() { actions.camera("菜单") }
    @objc private func saveFrameFromMenu() { rec.log("保存当前帧（模拟）", from: "菜单") }

    @objc private func magnifierFromMenu() {
        rec.toggleMagnifier()
        rec.log(rec.isMagnifierOn ? "打开放大镜" : "关闭放大镜", from: "菜单")
    }
}

// MARK: - 刘海胶囊（被评估的部分）

/// 刘海的轮廓：顶部贴着屏幕上沿，两个上角向外的内凹小弧（ear），两个下角圆角
struct NotchShape: Shape {
    var ear: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(ear, bottomRadius) }
        set {
            ear = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let e = max(0, min(ear, rect.width / 4, rect.height / 2))
        let b = max(0, min(bottomRadius, (rect.width - 2 * e) / 2, rect.height - e))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        if e > 0 {
            path.addArc(tangent1End: CGPoint(x: rect.minX + e, y: rect.minY),
                        tangent2End: CGPoint(x: rect.minX + e, y: rect.maxY), radius: e)
        }
        path.addArc(tangent1End: CGPoint(x: rect.minX + e, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: b)
        path.addArc(tangent1End: CGPoint(x: rect.maxX - e, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.maxX - e, y: rect.minY), radius: b)
        if e > 0 {
            path.addArc(tangent1End: CGPoint(x: rect.maxX - e, y: rect.minY),
                        tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: e)
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// 胶囊窗口的几何：窗口贴着屏幕顶部；坐标是 SwiftUI 的（左上角为原点）
struct CapsuleGeometry {
    let windowFrame: NSRect
    let start: CGRect          // 刘海的位置和大小；没有刘海时是菜单栏正中一条看不见的细线
    let final: CGRect          // 展开后的位置和大小
    let startRadius: CGFloat
    let startBlackOpacity: Double
    let finalEar: CGFloat      // 只有「刘海延伸」用

    static let contentSize = CGSize(width: 236, height: 40)

    static func make(screen: NSScreen, simulateNoNotch: Bool, style: CapsuleShapeStyle) -> CapsuleGeometry {
        let frame = screen.frame
        let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
        var notch: CGRect?
        if !simulateNoNotch, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let height = frame.maxY - min(left.minY, right.minY)
            notch = CGRect(x: left.maxX, y: frame.maxY - height, width: right.minX - left.maxX, height: height)
        }
        let content = contentSize
        let ear: CGFloat = 8
        let finalSize: CGSize
        let finalY: CGFloat
        switch style {
        case .pill, .notchRounded:
            finalSize = content
            finalY = menuBarHeight + 6
        case .notchExtended:
            // 从屏幕上沿一直延伸下来：上半截和刘海 / 菜单栏一样高，下半截放按钮
            finalSize = CGSize(width: content.width + ear * 2, height: (notch?.height ?? menuBarHeight) + content.height + 4)
            finalY = 0
        }
        let width = max(finalSize.width, notch?.width ?? 0) + 40 // 留出阴影和回弹的余量
        let height = finalY + finalSize.height + 24
        let midX = notch?.midX ?? frame.midX
        let windowFrame = NSRect(x: midX - width / 2, y: frame.maxY - height, width: width, height: height)
        let final = CGRect(x: (width - finalSize.width) / 2, y: finalY, width: finalSize.width, height: finalSize.height)
        let start = notch.map { CGRect(x: (width - $0.width) / 2, y: 0, width: $0.width, height: $0.height) }
            ?? CGRect(x: (width - content.width * 0.4) / 2, y: 0, width: content.width * 0.4, height: 1)
        return CapsuleGeometry(windowFrame: windowFrame, start: start, final: final,
                               startRadius: notch == nil ? 0.5 : 10, startBlackOpacity: notch == nil ? 0 : 1,
                               finalEar: style == .notchExtended ? ear : 0)
    }
}

@MainActor
final class CapsuleState: ObservableObject {
    @Published var expanded = false
    @Published var contentVisible = false
    @Published var opacity = 1.0
    @Published var countdown: Int?
}

struct NotchCapsuleView: View {
    @ObservedObject var rec: FakeRecording
    @ObservedObject var state: CapsuleState
    @ObservedObject var settings: DemoSettings
    let style: CapsuleShapeStyle // 形状决定几何，换形状要重新弹出；材质和圆角实时生效
    let geo: CapsuleGeometry
    let actions: DemoActions
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let rect = state.expanded ? geo.final : geo.start
        Group {
            switch style {
            case .pill:
                decorated(RoundedRectangle(cornerRadius: state.expanded ? geo.final.height / 2 : geo.startRadius,
                                           style: .continuous), rect: rect)
            case .notchRounded:
                decorated(RoundedRectangle(cornerRadius: state.expanded ? settings.cornerRadius : geo.startRadius,
                                           style: .continuous), rect: rect)
            case .notchExtended:
                decorated(NotchShape(ear: state.expanded ? geo.finalEar : 0,
                                     bottomRadius: state.expanded ? settings.cornerRadius + 4 : geo.startRadius), rect: rect)
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .frame(width: geo.windowFrame.width, height: geo.windowFrame.height)
        .opacity(state.opacity)
    }

    private func decorated<S: Shape>(_ shape: S, rect: CGRect) -> some View {
        let isBlack = settings.material == .black
        let base = content
            .frame(height: CapsuleGeometry.contentSize.height)
            .padding(.bottom, style == .notchExtended ? 4 : 0)
            .opacity(state.contentVisible ? 1 : 0)
            .blur(radius: state.contentVisible ? 0 : 4)
            .environment(\.colorScheme, isBlack ? .dark : colorScheme)
            .frame(width: rect.width, height: rect.height, alignment: style == .notchExtended ? .bottom : .center)
            // 起始的黑色块：藏在刘海里，下落过程中淡出，露出底下的材质
            .background(shape.fill(.black).opacity(isBlack || state.expanded ? 0 : geo.startBlackOpacity))
            .clipShape(shape)
        return withMaterial(base, shape: shape)
    }

    @ViewBuilder
    private func withMaterial<V: View, S: Shape>(_ view: V, shape: S) -> some View {
        switch settings.material {
        case .glass: view.glassEffect(.regular, in: shape)
        case .blur: view.background(.regularMaterial, in: shape)
        case .black: view.background(Color.black, in: shape)
        }
    }

    @ViewBuilder private var content: some View {
        if let n = state.countdown {
            HStack(spacing: 8) {
                Text("\(n)")
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                Text("秒后开始录制").font(.callout).foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 10) {
                Button { actions.stop("胶囊") } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.red))
                }
                Button { actions.pause("胶囊") } label: {
                    Image(systemName: rec.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                Text(rec.elapsedText)
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(rec.isPaused ? .secondary : .primary)
                    .frame(minWidth: 52)
                Divider().frame(height: 18)
                Button { actions.camera("胶囊") } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
            }
            .buttonStyle(.plain)
        }
    }
}

@MainActor
final class CapsuleController {
    private let rec: FakeRecording
    private let settings: DemoSettings
    private let actions: DemoActions
    private var state = CapsuleState()
    private var panel: NSPanel?
    private var generation = 0

    var isShown: Bool { panel != nil }
    var anchorView: NSView? { panel?.contentView }

    init(rec: FakeRecording, settings: DemoSettings, actions: DemoActions) {
        self.rec = rec
        self.settings = settings
        self.actions = actions
    }

    /// 从刘海弹出。倒计时开着时，倒计时结束才算开始录制（onStarted）
    func emerge(withCountdown: Bool, onStarted: @escaping @MainActor () -> Void) {
        panel?.orderOut(nil)
        generation += 1
        let gen = generation
        let screen = NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main
        guard let screen else { return }
        let geo = CapsuleGeometry.make(screen: screen, simulateNoNotch: settings.simulateNoNotch, style: settings.shape)
        let state = CapsuleState()
        state.countdown = withCountdown ? 3 : nil
        state.opacity = settings.reduceMotion ? 0 : 1
        self.state = state

        let view = NotchCapsuleView(rec: rec, state: state, settings: settings, style: settings.shape, geo: geo, actions: actions)
        let hosting = FirstMouseHostingView(rootView: view)
        hosting.sizingOptions = []
        let panel = KeyablePanel(contentRect: geo.windowFrame, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1) // 要能画到菜单栏区域
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.setFrame(geo.windowFrame, display: false)
        panel.orderFrontRegardless()
        self.panel = panel
        print("▶ 弹出：\(settings.lookText)；\(settings.motionText)\(settings.simulateNoNotch ? "，模拟无刘海" : "")\(withCountdown ? "，带倒计时" : "")")

        // 下一轮 runloop 再开始动画，确保起始状态（藏在刘海里）先被画出来
        DispatchQueue.main.async { [self] in
            guard gen == generation else { return }
            if settings.reduceMotion {
                state.expanded = true
                state.contentVisible = true
                withAnimation(.easeOut(duration: 0.25)) { state.opacity = 1 }
            } else {
                withAnimation(.spring(duration: settings.emergeDuration, bounce: settings.bounce)) { state.expanded = true }
                withAnimation(.smooth(duration: 0.25).delay(settings.emergeDuration * 0.4)) { state.contentVisible = true }
            }
            if withCountdown { runCountdown(gen: gen, onStarted: onStarted) } else { onStarted() }
        }
    }

    /// 收回刘海。录制本身已经先停了，这里只是视觉效果
    func retract() {
        guard let panel else { return }
        generation += 1
        let state = self.state
        let finish = { [weak self] in
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                if self?.panel === panel { self?.panel = nil }
            }
        }
        if settings.reduceMotion {
            withAnimation(.easeIn(duration: 0.2)) { state.opacity = 0 } completion: { finish() }
        } else {
            withAnimation(.smooth(duration: 0.12)) { state.contentVisible = false }
            withAnimation(.smooth(duration: 0.35).delay(0.08)) { state.expanded = false } completion: { finish() }
        }
    }

    private func runCountdown(gen: Int, onStarted: @escaping @MainActor () -> Void) {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, gen == self.generation, let n = self.state.countdown else {
                    timer.invalidate()
                    return
                }
                if n > 1 {
                    withAnimation(.smooth) { self.state.countdown = n - 1 }
                } else {
                    timer.invalidate()
                    withAnimation(.smooth) { self.state.countdown = nil }
                    onStarted()
                }
            }
        }
    }
}

/// 第一次点击直接交给按钮，不先被用来激活窗口
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct CameraPopoverPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("摄像头").font(.headline)
            Text("真实 app 里这里是摄像头 / 演讲者叠加的选择。\n用来确认 popover 在 macOS 27 上能正常弹出。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 280)
    }
}

// MARK: - 原型配置条（模拟设置页，不属于被评估的设计）

struct PrototypeConfigBar: View {
    @ObservedObject var settings: DemoSettings
    @ObservedObject var rec: FakeRecording
    let onConfigChange: @MainActor () -> Void
    let onStart: @MainActor () -> Void
    let onReplay: @MainActor () -> Void
    let onQuit: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("PROTOTYPE · 第 4 轮").font(.headline)
                Picker("形状", selection: $settings.shape) {
                    ForEach(CapsuleShapeStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                Picker("材质", selection: $settings.material) {
                    ForEach(CapsuleMaterial.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
            HStack(spacing: 10) {
                Text("圆角 \(settings.cornerRadius, specifier: "%.0f")").monospacedDigit()
                Slider(value: $settings.cornerRadius, in: 4...20, step: 1).frame(width: 140)
                    .disabled(settings.shape == .pill)
                Text("弹出时长 \(settings.emergeDuration, specifier: "%.2f")s").monospacedDigit()
                Slider(value: $settings.emergeDuration, in: 0.3...1.2).frame(width: 110)
                Text("回弹 \(settings.bounce, specifier: "%.2f")").monospacedDigit()
                Slider(value: $settings.bounce, in: 0...0.5).frame(width: 110)
            }
            HStack(spacing: 16) {
                Toggle("菜单栏计时 + 菜单", isOn: $settings.showMenuBarItem)
                    .disabled(settings.showMenuBarItem && !settings.showCapsule)
                Toggle("胶囊", isOn: $settings.showCapsule)
                    .disabled(settings.showCapsule && !settings.showMenuBarItem)
                Toggle("胶囊内倒计时", isOn: $settings.countdownOn).disabled(!settings.showCapsule)
                Toggle("模拟无刘海", isOn: $settings.simulateNoNotch)
                Toggle("减弱动态效果", isOn: $settings.reduceMotion)
            }
            Divider().overlay(.white.opacity(0.3))
            HStack(spacing: 10) {
                Text("状态：\(rec.stateText) \(rec.elapsedText)").monospacedDigit()
                Text("最近收到：\(rec.lastEvent)").lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
                if !rec.isRecording { Button("开始录制", action: onStart) }
                Button("重播动画", action: onReplay)
                Button("退出 Demo", action: onQuit)
            }
            .font(.caption)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 760)
        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.88)))
        .environment(\.colorScheme, .dark)
        .padding(8)
        .onChange(of: settings.showMenuBarItem) { onConfigChange() }
        .onChange(of: settings.showCapsule) { onConfigChange() }
        .onChange(of: settings.simulateNoNotch) { onReplay() }
        .onChange(of: settings.shape) { onReplay() }
    }
}

// MARK: - 入口

@main
@MainActor
final class PrototypeApp: NSObject, NSApplicationDelegate {
    private let settings = DemoSettings()
    private let rec = FakeRecording()
    private var menuBar: MenuBarController!
    private var capsule: CapsuleController!
    private let cameraPopover = NSPopover()
    private var configPanel: NSPanel?
    private var clock: Timer?

    static func main() {
        setvbuf(stdout, nil, _IOLBF, 0) // 输出重定向到文件时也逐行写出
        let app = NSApplication.shared
        let delegate = PrototypeApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for arg in CommandLine.arguments.dropFirst() {
            let parts = arg.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "shape", let shape = CapsuleShapeStyle(rawValue: parts[1]) { settings.shape = shape }
            if parts[0] == "material", let material = CapsuleMaterial(rawValue: parts[1]) { settings.material = material }
        }
        let actions = DemoActions(
            stop: { [weak self] in self?.stop(from: $0) },
            pause: { [weak self] in self?.pause(from: $0) },
            camera: { [weak self] in self?.camera(from: $0) }
        )
        menuBar = MenuBarController(rec: rec, settings: settings, actions: actions)
        capsule = CapsuleController(rec: rec, settings: settings, actions: actions)
        cameraPopover.behavior = .transient
        cameraPopover.contentViewController = NSHostingController(rootView: CameraPopoverPlaceholder())
        showConfigBar()

        let clock = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rec.tick()
                self?.menuBar.refresh()
            }
        }
        RunLoop.main.add(clock, forMode: .common) // .common：菜单打开时计时也继续走
        self.clock = clock
        print("菜单栏 demo 第 4 轮已启动。点配置条上的「退出 Demo」或在终端按 Ctrl+C 结束。")
        startFlow()
    }

    private func startFlow() {
        if settings.showCapsule {
            capsule.emerge(withCountdown: settings.countdownOn) { [weak self] in self?.beginRecording() }
        } else {
            beginRecording()
        }
    }

    private func beginRecording() {
        rec.start()
        menuBar.sync()
        print("● 开始录制（模拟）")
    }

    private func stop(from source: String) {
        guard rec.isRecording || capsule.isShown else { return }
        if rec.isRecording {
            rec.stop()
            rec.log("停止录制", from: source)
        }
        menuBar.sync()
        if cameraPopover.isShown { cameraPopover.performClose(nil) }
        capsule.retract()
    }

    private func pause(from source: String) {
        guard rec.isRecording else { return }
        rec.togglePause()
        rec.log(rec.isPaused ? "暂停" : "继续", from: source)
        menuBar.refresh()
    }

    private func camera(from source: String) {
        rec.log("打开摄像头弹窗", from: source)
        guard let anchor = menuBar.button ?? capsule.anchorView else { return }
        NSApp.activate()
        cameraPopover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: anchor.isFlipped ? .maxY : .minY)
    }

    private func replay() {
        stop(from: "重播按钮")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.startFlow() }
    }

    private func configChanged() {
        print("— 配置改为：\(settings.configText)")
        menuBar.sync()
        if settings.showCapsule, rec.isRecording, !capsule.isShown {
            capsule.emerge(withCountdown: false) {}
        } else if !settings.showCapsule, capsule.isShown {
            capsule.retract()
        }
    }

    private func showConfigBar() {
        let view = PrototypeConfigBar(
            settings: settings,
            rec: rec,
            onConfigChange: { [weak self] in self?.configChanged() },
            onStart: { [weak self] in self?.startFlow() },
            onReplay: { [weak self] in self?.replay() },
            onQuit: { NSApp.terminate(nil) }
        )
        let hosting = FirstMouseHostingView(rootView: view)
        let panel = KeyablePanel(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isMovableByWindowBackground = true
        if let frame = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 24))
        }
        panel.orderFrontRegardless()
        configPanel = panel
    }
}

//
//  PreviewCardPrototype.swift
//  PROTOTYPE — throwaway code for #55, not part of the app.
//
//  Question: how should the floating preview after a recording look and behave? Three layouts (thumbnail only,
//  info card, notification-like strip) on the panel material, for a video and for an audio recording; it slides in
//  from the right, a two-finger swipe right dismisses it, and dragging the thumbnail drags the file into other apps.
//  The sample files are generated into a temporary folder; nothing is deleted or trimmed, actions are only logged.
//

import AppKit
import AVFoundation
import SwiftUI

enum Layout: String, CaseIterable { case thumbnail = "A 缩略图式", card = "B 信息卡片式", strip = "C 横条式" }
enum PanelMaterial: String, CaseIterable { case glass = "Liquid Glass", blur = "毛玻璃", black = "纯黑" }
enum Content: String, CaseIterable { case video = "视频", audio = "音频" }

@MainActor
final class Model: ObservableObject {
    static let shared = Model()
    @Published var layout = Layout.strip
    @Published var material = PanelMaterial.glass
    @Published var content = Content.video
    @Published var autoHide = false
    /// How far the card has slid right of its place, and its opacity: the window itself stays put
    @Published var slide: CGFloat = 0
    @Published var fade: Double = 1
    @Published var lastAction = "（还没有操作）"
    var thumbnail = NSImage()
    var videoURL: URL!
    var audioURL: URL!

    var url: URL { content == .video ? videoURL : audioURL }
    var fileName: String { content == .video ? "录制于 2026-10-27 10.21.58.mp4" : "录制于 2026-10-27 10.23.40.m4a" }
    var duration: String { content == .video ? "0:21" : "0:14" }
    var size: String { content == .video ? "7.8 MB" : "143 KB" }

    func did(_ action: String) {
        lastAction = action
        print(action)
    }
}

/// The main panel's quit colour (`dark_my_red`)
let dangerRed = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0xEC / 255, green: 0x6A / 255, blue: 0x5D / 255, alpha: 1)
        : NSColor(srgbRed: 0xAA / 255, green: 0x1B / 255, blue: 0x0C / 255, alpha: 1)
})

// A speech-like envelope, standing in for the levels a real recording would be read for
let waveform: [CGFloat] = (0..<56).map { i in
    let x = Double(i)
    let speech = abs(sin(x * 0.45) * cos(x * 0.13)) * 0.8 + 0.12
    let pause = (20...25).contains(i) ? 0.12 : 1.0
    return CGFloat(min(1, speech * pause + Double((i * 37) % 11) / 60))
}

// MARK: - The preview card

struct PreviewCard: View {
    @EnvironmentObject var model: Model
    @Environment(\.colorScheme) private var colorScheme
    let dismiss: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack(alignment: .topLeading) {
            layout
                .padding(7)
            if hovering {
                // Top left on hover, like a notification's
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(.regularMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .offset(x: -5, y: -5)
                .transition(.opacity)
            }
        }
        .environment(\.colorScheme, model.material == .black ? .dark : colorScheme)
        .background { background(shape) }
        .padding(8)   // room for the close button and the shadow
        .offset(x: model.slide)
        .opacity(model.fade * (1 - min(0.5, model.slide / 400)))
        .onHover { inside in withAnimation(.easeOut(duration: 0.15)) { hovering = inside } }
        .contextMenu {
            Button("拷贝") { model.did("拷贝") }
            Button("共享…") { model.did("共享…") }
            if model.content == .video { Button("制作 GIF") { model.did("制作 GIF") } }
            Divider()
            Button("关闭") { dismiss() }
        }
    }

    @ViewBuilder private var layout: some View {
        switch model.layout {
        case .thumbnail:
            ZStack(alignment: .bottom) {
                media(width: 240, height: 150)
                if hovering {
                    actions
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
        case .card:
            VStack(alignment: .leading, spacing: 6) {
                media(width: 246, height: 140)
                info.padding(.horizontal, 4)
                actions.frame(maxWidth: .infinity)
            }
        case .strip:
            HStack(spacing: 10) {
                media(width: 120, height: 76)
                // The file name ends where the trash can does; audio has as many buttons as video, Copy taking Trim's place
                let buttons: CGFloat = 4
                let toTrash = buttons * 26 + (buttons - 1) * 2 - 5 - 6
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.fileName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: toTrash, alignment: .leading)
                            .help(model.fileName)
                        Text("\(model.duration) · \(model.size)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    actions.padding(.leading, -5)
                }
                .padding(.trailing, 4)
            }
        }
    }

    /// The first frame, or the recording's waveform; dragging it drags the file
    private func media(width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return ZStack(alignment: .bottomTrailing) {
            Group {
                if model.content == .video {
                    Image(nsImage: model.thumbnail).resizable().scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Waveform(levels: waveform).padding(.horizontal, width * 0.08).padding(.vertical, height * 0.2)
                    }
                }
            }
            .frame(width: width, height: height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            Text(model.duration)
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(5)
        }
        .onDrag {
            model.did("拖出文件：\(model.url.lastPathComponent)")
            return NSItemProvider(contentsOf: model.url) ?? NSItemProvider()
        }
        .onTapGesture(count: 2) { open() }
        .help("拖到其他 app 里发送文件，双击打开")
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(model.fileName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(model.duration) · \(model.size)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: 2) {
            IconButton(symbol: "play.fill", help: "打开") { open() }
            IconButton(symbol: "folder", help: "在访达中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([model.url])
                model.did("在访达中显示")
            }
            // The third place is always taken, so Delete never moves under a pointer used to the video card
            if model.content == .video {
                IconButton(symbol: "scissors", help: "剪辑") { model.did("剪辑（原型里不执行）") }
            } else {
                IconButton(symbol: "doc.on.doc", help: "拷贝") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([model.url as NSURL])
                    model.did("拷贝（可以粘贴到聊天或访达里）")
                }
            }
            IconButton(symbol: "trash", help: "删除", hoverTint: dangerRed) { model.did("删除（原型里不执行）") }
        }
    }

    private func open() {
        NSWorkspace.shared.open(model.url)
        model.did("打开")
    }

    @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
        switch model.material {
        case .glass: Color.clear.glassEffect(.regular, in: shape)
        case .blur: shape.fill(.regularMaterial).environment(\.controlActiveState, .active)
        case .black: shape.fill(.black)
        }
    }
}

struct Waveform: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            // One bar every 4 points, each the loudest of the levels it covers
            let count = max(1, min(levels.count, Int(geometry.size.width / 4)))
            let bars = (0..<count).map { bar in
                levels[(bar * levels.count / count)..<max(bar * levels.count / count + 1, (bar + 1) * levels.count / count)].max() ?? 0
            }
            HStack(alignment: .center, spacing: 0) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(0.9))
                        .frame(width: 2, height: max(2, bars[i] * geometry.size.height))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
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
                .font(.system(size: 13))
                .foregroundStyle(hovering ? AnyShapeStyle(hoverTint) : AnyShapeStyle(.secondary))
                .frame(width: 26, height: 26)
                .background(.primary.opacity(hovering ? 0.12 : 0.0001), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Sample files and thumbnail

/// A desktop with two windows, as a recording's first frame
struct MockDesktop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.25, green: 0.35, blue: 0.75), Color(red: 0.75, green: 0.4, blue: 0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            window(title: "Safari").frame(width: 700, height: 460).offset(x: -160, y: -40)
            window(title: "备忘录").frame(width: 420, height: 300).offset(x: 300, y: 120)
        }
        .frame(width: 1280, height: 800)
    }

    private func window(title: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 14, height: 14) }
                Spacer()
            }
            .padding(14)
            .background(Color(white: 0.93))
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill(Color.gray.opacity(0.3)).frame(width: CGFloat(200 + (i * 83) % 300), height: 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }
}

/// Two seconds of the thumbnail as an H.264 movie, so the file can be opened and dragged
func writeSampleVideo(_ image: CGImage, to url: URL) throws {
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: image.width, AVVideoHeightKey: image.height])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: image.width, kCVPixelBufferHeightKey as String: image.height])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<20 {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        CVPixelBufferLockBaseAddress(buffer!, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer!), width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer!), space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(buffer!, [])
        adaptor.append(buffer!, withPresentationTime: CMTime(value: Int64(frame), timescale: 10))
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
}

/// Three seconds of a rising and falling tone
func writeSampleAudio(to url: URL) throws {
    try? FileManager.default.removeItem(at: url)
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
    let frames = AVAudioFrameCount(44100 * 3)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    for i in 0..<Int(frames) {
        let t = Double(i) / 44100
        buffer.floatChannelData![0][i] = Float(sin(2 * .pi * (330 + 110 * sin(t * 2)) * t) * 0.3 * sin(.pi * t / 3))
    }
    try file.write(from: buffer)
}

// MARK: - Info window

struct InfoView: View {
    @EnvironmentObject var model: Model
    let replay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预览浮窗原型（#55）").font(.headline)
            Text("右下角就是录制结束后的预览浮窗。它会从右边滑进来；鼠标移上去会出现操作按钮和左上角的 ×；双指向右轻扫可以关掉；把缩略图拖进访达、微信、邮件等 app，就是直接发送这个文件；双击缩略图打开文件。右键还有拷贝、共享、GIF。这里用的是临时生成的示例文件，删除、剪辑只做记录，不会真的执行。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("布局").foregroundStyle(.secondary)
                    Picker("", selection: $model.layout) { ForEach(Layout.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                GridRow {
                    Text("内容").foregroundStyle(.secondary)
                    Picker("", selection: $model.content) { ForEach(Content.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                GridRow {
                    Text("材质").foregroundStyle(.secondary)
                    Picker("", selection: $model.material) { ForEach(PanelMaterial.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                GridRow {
                    Text("自动消失").foregroundStyle(.secondary)
                    Toggle("6 秒内没有操作就滑出去（看样式时可以先关着）", isOn: $model.autoHide)
                }
                GridRow { Text("上次操作").foregroundStyle(.secondary); Text(model.lastAction) }
            }
            .font(.callout)
            HStack {
                Button("重新弹出", action: replay)
                Spacer()
                Button("退出原型") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 500)
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var host: NSHostingView<AnyView>!
    var window: NSWindow!
    var hideTimer: Timer?
    var observers = [Any]()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = Model.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PROTOTYPE preview-card", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let renderer = ImageRenderer(content: MockDesktop())
        if let cgImage = renderer.cgImage {
            model.thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            model.videoURL = folder.appendingPathComponent(model.fileName)
            try? writeSampleVideo(cgImage, to: model.videoURL)
        }
        model.audioURL = folder.appendingPathComponent("录制于 2026-10-27 10.23.40.m4a")
        try? writeSampleAudio(to: model.audioURL)

        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        host = NSHostingView(rootView: AnyView(PreviewCard { [unowned self] in dismiss() }.environmentObject(model)))
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces]

        // A two-finger swipe right dismisses it, as with notifications
        observers.append(NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [unowned self] event in
            guard event.window === panel else { return event }
            if event.phase == .changed || event.phase == .began { model.slide = max(0, model.slide + event.scrollingDeltaX) }
            if event.phase == .ended || event.phase == .cancelled {
                if model.slide > 60 { dismiss() } else { withAnimation(.snappy) { model.slide = 0 } }
            }
            return nil
        } as Any)
        observers.append(model.objectWillChange.sink { [unowned self] _ in
            // After SwiftUI has laid out the change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.refit() }
        })

        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "预览浮窗原型"
        window.contentViewController = NSHostingController(rootView: InfoView { [unowned self] in present() }.environmentObject(model))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        let shot = CommandLine.arguments.firstIndex(of: "--shot")
        if let i = shot {
            model.layout = Layout.allCases[Int(CommandLine.arguments[i + 1])!]
            model.content = Content.allCases[Int(CommandLine.arguments[i + 2])!]
            model.material = PanelMaterial.allCases[Int(CommandLine.arguments[i + 3])!]
        }
        present()
        // --shot <layout 0-2> <content 0-1> <material 0-2> <out.png>: captures the card once it has slid in, then quits
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--shot"), args.count > i + 4 {
            window.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [unowned self] in
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", "\(panel.windowNumber)", args[i + 4]]
                try? capture.run()
                capture.waitUntilExit()
                NSApp.terminate(nil)
            }
        }
    }

    /// Flush with the screen's right edge, so the card sliding out of the window slides off the screen
    private var target: NSRect {
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let visible = NSScreen.main?.visibleFrame ?? .zero
        return NSRect(x: visible.maxX - size.width, y: visible.minY + 8, width: size.width, height: size.height)
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Slides in from the right edge. The card moves inside a window that stays put: SwiftUI animates it on the GPU,
    /// where moving the window frame by frame stutters.
    func present() {
        let model = Model.shared
        panel.hasShadow = model.material != .glass
        panel.setFrame(target, display: false)
        model.slide = reduceMotion ? 0 : target.width
        model.fade = reduceMotion ? 0 : 1
        panel.orderFrontRegardless()
        DispatchQueue.main.async { [unowned self] in
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.2, 0.9, 0.3, 1, duration: 0.35)) {
                model.slide = 0
                model.fade = 1
            }
        }
        scheduleHide()
    }

    /// Slides out to the right from wherever the card is, a swipe included: quick at first, easing off as it fades
    func dismiss() {
        hideTimer?.invalidate()
        let model = Model.shared
        withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .smooth(duration: 0.3)) {
            if !reduceMotion { model.slide = panel.frame.width }
            model.fade = 0
        } completion: { [unowned self] in
            panel.orderOut(nil)
            model.slide = 0
            model.fade = 1
            model.did("关闭")
        }
    }

    private func refit() {
        guard panel.isVisible, Model.shared.slide == 0, Model.shared.fade == 1 else { return }
        panel.hasShadow = Model.shared.material != .glass
        panel.setFrame(target, display: true)
        scheduleHide()
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        guard Model.shared.autoHide else { return }
        hideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [unowned self] _ in
            MainActor.assumeIsolated {
                // Not while the pointer is on it
                if panel.frame.contains(NSEvent.mouseLocation) { scheduleHide() } else { dismiss() }
            }
        }
    }
}

@main
struct PreviewCardPrototype {
    @MainActor static let delegate = AppDelegate()

    @MainActor static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

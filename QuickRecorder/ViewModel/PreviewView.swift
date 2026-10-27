//
//  PreviewView.swift
//  QuickRecorder
//
//  Created by apple on 2024/12/10.
//
//  The floating preview after a recording (#55): a strip with the first frame or the audio's waveform, the file's name,
//  length and size, and Open, Show in Finder, Trim and Delete. It slides in from the right edge, a two-finger swipe
//  right dismisses it, and dragging the thumbnail drags the file into other apps.
//

import SwiftUI
import AVFoundation

/// Shows the preview in `previewWindow` and moves it in and out.
@MainActor
final class PreviewController: ObservableObject {
    static let shared = PreviewController()

    @Published private(set) var url = URL(fileURLWithPath: "/")
    /// The first frame of a video; nil for audio, which shows `levels`
    @Published private(set) var frame: NSImage?
    @Published private(set) var levels = [Float](repeating: 0, count: 28)
    @Published private(set) var length = ""
    @Published private(set) var size = ""
    /// How far the card has slid right of its place, and its opacity: the window itself stays put, since moving
    /// a window frame by frame stutters where SwiftUI animates the card smoothly
    @Published var slide: CGFloat = 0
    @Published var fade: Double = 1
    var isSharing = false

    private var hideTimer: Timer?
    private var scrollMonitor: Any?
    private lazy var host = NSHostingView(rootView: PreviewView(card: self))

    var isAudio: Bool { url.pathExtension.lowercased() == "m4a" }

    func show(url: URL, frame: NSImage?) {
        hideTimer?.invalidate()
        self.url = url
        self.frame = frame
        levels = [Float](repeating: 0, count: levels.count)
        length = ""
        size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? ""
        Task {
            if let seconds = try? await AVURLAsset(url: url).load(.duration).seconds { length = RecordingPreview.duration(seconds) }
        }
        if isAudio {
            let bars = levels.count
            Task.detached(priority: .userInitiated) {
                let levels = (try? RecordingPreview.waveform(of: url, bars: bars)) ?? []
                await MainActor.run { if self.url == url, !levels.isEmpty { self.levels = levels } }
            }
        }
        present()
    }

    private func present() {
        let window = previewWindow
        if window.contentView !== host { window.contentView = host }
        window.isOpaque = false
        // The window shadow outlines a borderless window in a dark line, which shows as a black rim around Liquid Glass
        window.hasShadow = ud.string(forKey: "capsuleMaterial") != PanelMaterial.glass.rawValue
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        // Flush with the screen's right edge, so the card sliding out of the window slides off the screen
        let visible = (SCContext.getScreenWithMouse() ?? NSScreen.main)?.visibleFrame ?? .zero
        window.setFrame(NSRect(x: visible.maxX - size.width, y: visible.minY + 8, width: size.width, height: size.height), display: false)
        slide = reduceMotion ? 0 : size.width
        fade = reduceMotion ? 0 : 1
        window.orderFrontRegardless()
        watchSwipes()
        DispatchQueue.main.async {
            withAnimation(self.reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.2, 0.9, 0.3, 1, duration: 0.35)) {
                self.slide = 0
                self.fade = 1
            }
        }
        scheduleHide()
    }

    /// Slides out to the right from wherever the card is, a swipe included: quick at first, easing off as it fades.
    func dismiss() {
        hideTimer?.invalidate()
        withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .smooth(duration: 0.3)) {
            if !reduceMotion { slide = previewWindow.frame.width }
            fade = 0
        } completion: {
            previewWindow.orderOut(nil)
            self.slide = 0
            self.fade = 1
        }
    }

    /// Six seconds after it appears, or after the pointer leaves it; never under the pointer or while sharing
    func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { _ in
            MainActor.assumeIsolated {
                if previewWindow.frame.contains(NSEvent.mouseLocation) || self.isSharing { self.scheduleHide() } else { self.dismiss() }
            }
        }
    }

    /// A two-finger swipe right dismisses it, as with notifications: the card follows the fingers
    private func watchSwipes() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard event.window === previewWindow else { return event }
            MainActor.assumeIsolated {
                let card = PreviewController.shared
                if event.phase == .began || event.phase == .changed {
                    card.slide = max(0, card.slide + event.scrollingDeltaX)
                } else if event.phase == .ended || event.phase == .cancelled {
                    if card.slide > 60 { card.dismiss() } else { withAnimation(.snappy) { card.slide = 0 } }
                }
            }
            return nil
        }
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

struct PreviewView: View {
    @ObservedObject var card: PreviewController
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    private let sharingDelegate = SharingServicePickerDelegate()

    /// Four buttons for video and audio alike; the file name ends where the last, Delete, does
    private let nameWidth: CGFloat = 4 * 26 + 3 * 2 - 5 - 6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack(alignment: .topLeading) {
            HStack(spacing: 10) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.url.lastPathComponent)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: nameWidth, alignment: .leading)
                            .help(card.url.lastPathComponent)
                        Text([card.length, card.size].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    actions.padding(.leading, -5)
                }
                .padding(.trailing, 4)
            }
            .padding(7)
            if hovering {
                // Top left on hover, like a notification's
                Button { card.dismiss() } label: {
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
                .help("Close".local)
            }
        }
        .environment(\.colorScheme, material == .black ? .dark : colorScheme)
        .background { background(shape) }
        .padding(8)   // room for the close button and the shadow
        .offset(x: card.slide)
        .opacity(card.fade * (1 - min(0.5, card.slide / 400)))
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.15)) { hovering = inside }
            if !inside { card.scheduleHide() }
        }
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([card.url as NSURL])
                card.dismiss()
            }
            Button("Share…") { share() }
            if !card.isAudio { Button("Make GIF") { makeGif() } }
            Divider()
            Button("Close") { card.dismiss() }
        }
    }

    /// The first frame, or the recording's waveform, with its length; dragging it drags the file
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return ZStack(alignment: .bottomTrailing) {
            Group {
                if let frame = card.frame {
                    Image(nsImage: frame).resizable().scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        if card.isAudio {
                            Waveform(levels: card.levels).padding(.horizontal, 10).padding(.vertical, 15)
                        } else {
                            Image(systemName: "film").font(.system(size: 24)).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
            }
            .frame(width: 120, height: 76)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            if !card.length.isEmpty {
                Text(card.length)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(5)
            }
        }
        .onDrag { NSItemProvider(contentsOf: card.url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { open() }
        .help("Drag into another app to send the file; double-click to open it.".local)
    }

    private var actions: some View {
        HStack(spacing: 2) {
            IconButton(symbol: "play.fill", help: "Open".local) { open() }
            IconButton(symbol: "folder", help: "Show in Finder".local) {
                NSWorkspace.shared.activateFileViewerSelecting([card.url])
                card.dismiss()
            }
            IconButton(symbol: "scissors", help: "Trim".local) {
                AppDelegate.shared.createNewWindow(view: VideoTrimmerView(videoURL: card.url), title: card.url.lastPathComponent, only: false)
                card.dismiss()
            }
            IconButton(symbol: "trash", help: "Move to Trash".local, hoverTint: .darkMyRed) {
                // To the Trash rather than gone for good: a slip of the pointer can be undone
                try? FileManager.default.trashItem(at: card.url, resultingItemURL: nil)
                card.dismiss()
            }
        }
    }

    private func open() {
        NSWorkspace.shared.open(card.url)
        card.dismiss()
    }

    @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
        switch material {
        case .glass: Color.clear.glassEffect(.regular, in: shape)
        case .blur: shape.fill(.regularMaterial).environment(\.controlActiveState, .active)
        case .black: shape.fill(.black)
        }
    }

    private func makeGif() {
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sindresorhus.Gifski") != nil {
            NSWorkspace.shared.open([card.url], withApplicationAt: NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sindresorhus.Gifski")!,
                                    configuration: NSWorkspace.OpenConfiguration())
            card.dismiss()
        } else {
            let alert = createAlert(title: "Gifski not found", message: "Please install \"Gifski\" first to make GIF!",
                                    button1: "Open App Store", button2: "Cancel").runModal()
            if alert == .alertFirstButtonReturn, let url = URL(string: "https://apps.apple.com/app/id1351639930") { NSWorkspace.shared.open(url) }
        }
    }

    private func share() {
        guard let view = previewWindow.contentView else { return }
        card.isSharing = true
        sharingDelegate.onDidChooseService = { service in
            card.isSharing = false
            if service != nil { DispatchQueue.main.async { card.dismiss() } } else { card.scheduleHide() }
        }
        let picker = NSSharingServicePicker(items: [card.url])
        picker.delegate = sharingDelegate
        picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
    }
}

/// An audio recording's levels as bars, one every 4 points
struct Waveform: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geometry in
            let count = max(1, min(levels.count, Int(geometry.size.width / 4)))
            let bars = (0..<count).map { bar in
                levels[(bar * levels.count / count)..<max(bar * levels.count / count + 1, (bar + 1) * levels.count / count)].max() ?? 0
            }
            HStack(alignment: .center, spacing: 0) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(0.9))
                        .frame(width: 2, height: max(2, CGFloat(bars[i]) * geometry.size.height))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.smooth(duration: 0.3), value: levels)
        }
    }
}

class SharingServicePickerDelegate: NSObject, NSSharingServicePickerDelegate {
    var onDidChooseService: ((NSSharingService?) -> Void)?

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        onDidChooseService?(service)
    }
}

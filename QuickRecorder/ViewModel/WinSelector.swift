//
//  WinSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/17.
//

import SwiftUI
import Foundation
import AVFoundation
@preconcurrency import ScreenCaptureKit

struct WinSelector: View {
    @StateObject var viewModel = WindowSelectorViewModel()
    @State private var selected = [SCWindow]()
    @State private var display: SCDisplay!
    @State private var disableFilter = false
    @State private var donotCapture = false
    var appDelegate = AppDelegate.shared

    var body: some View {
        VStack(spacing: 15) {
            Text("Please select the window(s) to record").offset(y: 12)
            DisplayTabs(items: { viewModel.windowThumbnails }, isReady: viewModel.$isReady, windowTitle: "Window Selector".local,
                        onShow: { display = $0 }, onSwitch: { selected.removeAll() }) { screen, thumbnails in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(0..<thumbnails.count/4 + 1, id: \.self) { rowIndex in
                            HStack(spacing: 8) {
                                ForEach(0..<4, id: \.self) { columnIndex in
                                    let index = 4 * rowIndex + columnIndex
                                    if index <= thumbnails.count - 1 {
                                        let item = thumbnails[index]
                                        SelectableCard(title: item.window.title!, titleWidth: 160, chosen: selected.contains(item.window), action: {
                                            if !selected.contains(item.window) { selected.append(item.window) } else { selected.removeAll { $0 == item.window } }
                                        }) {
                                            ShadowedThumbnail(image: item.image)
                                                .frame(width: 160, height: 90, alignment: .center)
                                                .overlay(alignment: .bottom) {
                                                    Image(nsImage: SCContext.getAppIcon(item.window.owningApplication!)!)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 40, height: 40)
                                                        .offset(y: 10)
                                                }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12).padding(.top, 5)
                        }
                    }
                    // Room for the ring and the tick of a chosen card
                    .padding(.top, 8)
                }
            }
            // Refresh's own settings, as a right-click opens the microphone's and the timer's. Picking a window on the
            // screen sits right of it, where the area selector keeps 「窗口范围」 (#144)
            SelectorCapsule(leading: [CapsuleLeading(symbol: "arrow.clockwise", label: "Refresh".local, spins: true, action: refresh,
                                                     bubble: AnyView(listSettings)),
                                      CapsuleLeading(symbol: "macwindow", label: "Select Window Directly".local,
                                                     action: { WindowHighlighter.shared.registerMouseMonitor() })],
                            screen: display?.nsScreen ?? NSScreen.main, canStart: selected.count >= 1) {
                startRecording(autoStop: $0)
            }
            Spacer()
        }
        .padding(.top, -5)
        .frame(width: 780, height:555)
        // Esc clears the chosen windows first, and only closes the picker when nothing is chosen (#153)
        .escapeClearsSelection($selected)
    }
    
    func startRecording(autoStop: TimeInterval) {
        closeAllWindow()
        appDelegate.countdownAndRecord(type: selected.count < 2 ? "window" : "windows", screen: display, windows: selected, autoStop: autoStop)
    }

    private func refresh() {
        viewModel.setupStreams(filter: !disableFilter, capture: !donotCapture)
        selected.removeAll()
    }

    /// Which windows the list shows, and whether it makes their thumbnails
    private var listSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            BubbleRow(title: "Show Windows with No Title".local, checked: disableFilter) { disableFilter.toggle(); refresh() }
            BubbleRow(title: "Don't Create Thumbnails".local, checked: donotCapture) { donotCapture.toggle(); refresh() }
        }
        .frame(width: 200)
    }
}

@MainActor
class WindowSelectorViewModel: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    @Published var windowThumbnails = [SCDisplay:[WindowThumbnail]]()
    @Published var isReady = false
    private var allWindows = [SCWindow]()
    private var streams = [SCStream]()
    
    override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupStreams()
        }
    }
    
    // Registered with sampleHandlerQueue: .main, so this always runs on the main thread
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        MainActor.assumeIsolated {
            if CMSampleBufferGetImageBuffer(sampleBuffer) == nil { return }
            let nsImage = sampleBuffer.nsImage ?? NSImage.unknowScreen
            if let index = self.streams.firstIndex(of: stream), index + 1 <= self.allWindows.count {
                let currentWindow = self.allWindows[index]
                let thumbnail = WindowThumbnail(image: nsImage, window: currentWindow)
                guard let displays = SCContext.availableContent?.displays.filter({ NSIntersectsRect(currentWindow.frame, $0.frame) }) else {
                    self.streams[index].stopCapture()
                    return
                }
                for d in displays {
                    DispatchQueue.main.async {
                        if self.windowThumbnails[d] != nil {
                            if !self.windowThumbnails[d]!.contains(where: { $0.window == currentWindow }) { self.windowThumbnails[d]!.append(thumbnail) }
                        } else {
                            self.windowThumbnails[d] = [thumbnail]
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.streams[index].stopCapture() }
                if index + 1 == self.streams.count { DispatchQueue.main.async { self.isReady = true }}
            }
        }
    }

    func setupStreams(filter: Bool = true, capture: Bool = true) {
        SCContext.updateAvailableContent {
            Task { @MainActor in
                do {
                    self.streams.removeAll()
                    DispatchQueue.main.async { self.windowThumbnails.removeAll() }
                    self.allWindows = SCContext.getWindows().filter({
                        !($0.title == "" && $0.owningApplication?.bundleIdentifier == "com.apple.finder")
                        && $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                        && $0.owningApplication?.applicationName != ""
                    })
                    if filter { self.allWindows = self.allWindows.filter({ $0.title != "" }) }
                    if capture {
                        let contentFilters = self.allWindows.map { SCContentFilter(desktopIndependentWindow: $0) }
                        for (index, contentFilter) in contentFilters.enumerated() {
                            let streamConfiguration = SCStreamConfiguration()
                            let width = self.allWindows[index].frame.width
                            let height = self.allWindows[index].frame.height
                            var factor = 0.5
                            if width < 200 && height < 200 { factor = 1.0 }
                            streamConfiguration.width = Int(width * factor)
                            streamConfiguration.height = Int(height * factor)
                            streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(1))
                            streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
                            streamConfiguration.capturesAudio = false
                            streamConfiguration.showsCursor = false
                            streamConfiguration.scalesToFit = true
                            streamConfiguration.queueDepth = 3
                            let stream = SCStream(filter: contentFilter, configuration: streamConfiguration, delegate: self)
                            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                            try await stream.startCapture()
                            self.streams.append(stream)
                        }
                    } else {
                        for w in self.allWindows {
                            let thumbnail = WindowThumbnail(image: NSImage.unknowScreen, window: w)
                            guard let displays = SCContext.availableContent?.displays.filter({ NSIntersectsRect(w.frame, $0.frame) }) else { break }
                            for d in displays {
                                DispatchQueue.main.async {
                                    if self.windowThumbnails[d] != nil {
                                        if !self.windowThumbnails[d]!.contains(where: { $0.window == w }) {
                                            self.windowThumbnails[d]!.append(thumbnail)
                                        }
                                    } else {
                                        self.windowThumbnails[d] = [thumbnail]
                                    }
                                }
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.isReady = true }
                    }
                } catch {
                    print("Get windowshot error：\(error)")
                }
            }
        }
    }
}

class WindowThumbnail {
    let image: NSImage
    let window: SCWindow

    init(image: NSImage, window: SCWindow) {
        self.image = image
        self.window = window
    }
}

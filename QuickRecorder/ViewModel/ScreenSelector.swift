//
//  ScreenSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/18.
//

import SwiftUI
@preconcurrency import ScreenCaptureKit

struct ScreenSelector: View {
    @StateObject var viewModel = ScreenSelectorViewModel()

    @State private var selected: SCDisplay?
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 15) {
                Text("Please select the screen to record")
                let count = viewModel.screenThumbnails.count
                ScrollView(.vertical) {
                    VStack(spacing: 14){
                        ForEach(0..<viewModel.screenThumbnails.count/2 + 1, id: \.self) { rowIndex in
                            HStack(spacing: 30) {
                                ForEach(0..<2, id: \.self) { columnIndex in
                                    let index = 2 * rowIndex + columnIndex
                                    if index <= viewModel.screenThumbnails.count - 1 {
                                        Button(action: {
                                            selected = viewModel.screenThumbnails[index].screen
                                        }, label: {
                                            ZStack {
                                                VStack(spacing: 4) {
                                                    ShadowedThumbnail(image: viewModel.screenThumbnails[index].image)
                                                        .frame(width: count == 1 ? 672 : 320, height: count == 1 ? 378 : 180, alignment: .center)
                                                    let screenName = NSScreen.screens.first(where: { $0.displayID == viewModel.screenThumbnails[index].screen.displayID })?.localizedName ?? "Display ".local + "\(viewModel.screenThumbnails[index].screen.displayID)"
                                                    Text(screenName)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .offset(y:count == 1 ? 5 : 2)
                                                }
                                                .padding(count == 1 ? 19 : 10)
                                                .background(SelectionBackground(selected: selected == viewModel.screenThumbnails[index].screen))
                                                SelectionMark(selected: selected == viewModel.screenThumbnails[index].screen, size: count == 1 ? 54 : 27)
                                                    .offset(x: count == 1 ? 270 : 120, y: count == 1 ? 130 : 50)
                                            }
                                        }).buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 35)
                        }
                    }
                }
                .frame(height: 445)
                
                HStack(spacing: 4) {
                    BarButton(icon: "arrow.clockwise.circle.fill", style: .blue, title: "Refresh") { viewModel.setupStreams() }
                    Spacer()
                    OptionsView(showsBackground: false).padding(.leading, 18)
                    Spacer()
                    StartControls(canStart: selected != nil) { autoStop in startRecording(autoStop: autoStop) }
                }.padding(.horizontal, 40)
                Spacer()
            }
            .padding(.top, -5)
        }.frame(width: 780, height:555)
    }

    func startRecording(autoStop: Int) {
        closeAllWindow()
        if let screen = selected {
            appDelegate.countdownAndRecord(type: "display", screen: screen, autoStop: autoStop)
        }
    }
}

@MainActor
class ScreenSelectorViewModel: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    @Published var screenThumbnails = [ScreenThumbnail]()
    private var allScreens = [SCDisplay]()
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
            var nsImage = sampleBuffer.nsImage
            if let index = self.streams.firstIndex(of: stream), index + 1 <= self.allScreens.count {
                if nsImage == nil { nsImage = SCContext.getWallpaper(self.allScreens[index]) ?? NSImage.unknowScreen }
                let currentScreen = self.allScreens[index]
                let thumbnail = ScreenThumbnail(image: nsImage!, screen: currentScreen)
                DispatchQueue.main.async {
                    if !self.screenThumbnails.contains(where: { $0.screen == currentScreen }) { self.screenThumbnails.append(thumbnail) }
                }
                self.streams[index].stopCapture()
            }
        }
    }

    func setupStreams() {
        SCContext.updateAvailableContent {
            Task { @MainActor in
                do {
                    self.streams.removeAll()
                    DispatchQueue.main.async { self.screenThumbnails.removeAll() }
                    guard let screens = SCContext.availableContent?.displays else { return }
                    self.allScreens = screens
                    let qrSelf = SCContext.getSelf()
                    let contentFilters = self.allScreens.map { SCContentFilter(display: $0, excludingApplications: qrSelf != nil ? [qrSelf!] : [], exceptingWindows: []) }
                    for (index, contentFilter) in contentFilters.enumerated() {
                        let streamConfiguration = SCStreamConfiguration()
                        streamConfiguration.width = Int(self.allScreens[index].frame.width)
                        streamConfiguration.height = Int(self.allScreens[index].frame.height)
                        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(1))
                        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
                        streamConfiguration.capturesAudio = false
                        streamConfiguration.showsCursor = false
                        streamConfiguration.queueDepth = 3
                        let stream = SCStream(filter: contentFilter, configuration: streamConfiguration, delegate: self)
                        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                        try await stream.startCapture()
                        self.streams.append(stream)
                    }
                } catch {
                    print("Get screenshot error：\(error)")
                }
            }
        }
    }
}

class ScreenThumbnail {
    let image: NSImage
    let screen: SCDisplay

    init(image: NSImage, screen: SCDisplay) {
        self.image = image
        self.screen = screen
    }
}

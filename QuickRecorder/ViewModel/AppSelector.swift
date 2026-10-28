//
//  AppSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI
import Combine
import ScreenCaptureKit

struct AppSelector: View {
    @StateObject var viewModel = AppSelectorViewModel()
    @State private var selected = [SCRunningApplication]()
    @State private var display: SCDisplay!
    var appDelegate = AppDelegate.shared

    var body: some View {
        ZStack {
            VStack(spacing: 15) {
                Text("Please select the App(s) to record").offset(y: 12)
                DisplayTabs(items: { viewModel.allApps }, isReady: viewModel.$isReady, windowTitle: "App Selector".local,
                            onShow: { display = $0 }, onSwitch: { selected.removeAll() }) { screen, apps in
                    ScrollView(.vertical) {
                        VStack(spacing: 8) {
                            ForEach(0..<apps.count/5 + 1, id: \.self) { rowIndex in
                                HStack(spacing: 20) {
                                    ForEach(0..<5, id: \.self) { columnIndex in
                                        let index = 5 * rowIndex + columnIndex
                                        if index <= apps.count - 1 {
                                            let item = apps[index]
                                            Button(action: {
                                                if !selected.contains(item) {
                                                    selected.append(item)
                                                } else {
                                                    selected.removeAll{ $0 == item }
                                                }
                                            }, label: {
                                                ZStack {
                                                    VStack {
                                                        Image(nsImage: SCContext.getAppIcon(item)!)
                                                        let appName = item.applicationName
                                                        let appID = item.bundleIdentifier
                                                        Text(appName != "" ? appName : appID)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)
                                                            .truncationMode(.tail)
                                                    }
                                                    .frame(width: 110, height: 94)
                                                    .padding(10)
                                                    .background(SelectionBackground(selected: selected.contains(item)))
                                                    SelectionMark(selected: selected.contains(item))
                                                        .offset(x: 20, y: 10)
                                                }
                                            }).buttonStyle(.plain)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 12).padding(.top, 4)
                            }
                        }
                    }
                }
                HStack(spacing: 4) {
                    BarButton(icon: "arrow.clockwise.circle.fill", style: .blue, title: "Refresh") { viewModel.updateAppList() }
                    Spacer()
                    OptionsView().padding(.leading, 18)
                    Spacer()
                    StartControls(canStart: selected.count >= 1) { autoStop in startRecording(autoStop: autoStop) }
                }.padding(.horizontal, 40)
                Spacer()
            }.padding(.top, -5)
        }.frame(width: 780, height:555)
    }

    func startRecording(autoStop: Int) {
        closeAllWindow()
        appDelegate.countdownAndRecord(type: "application", screen: display, applications: selected, autoStop: autoStop)
    }
}

class AppSelectorViewModel: ObservableObject {
    @Published var allApps = [SCDisplay: [SCRunningApplication]]()
    @Published var isReady = false
    
    init() {
        updateAppList()
    }
    
    func updateAppList() {
        SCContext.updateAvailableContent {
            guard let screens = SCContext.availableContent?.displays else { return }
            for screen in screens {
                var apps = [SCRunningApplication]()
                let windows = SCContext.getWindows().filter({ NSIntersectsRect(screen.frame, $0.frame) })
                for app in windows.map({ $0.owningApplication }) { if !apps.contains(app!) { apps.append(app!) }}
                if ud.bool(forKey: "hideSelf") { apps = apps.filter({$0.bundleIdentifier != Bundle.main.bundleIdentifier}) }
                DispatchQueue.main.async { self.allApps[screen] = apps }
            }
            DispatchQueue.main.async { self.isReady = true }
        }
    }
    
    /*func updateAppList() {
        SCContext.updateAvailableContent{
            DispatchQueue.main.async {
                self.allApps = SCContext.getApps().filter({ $0.bundleIdentifier != Bundle.main.bundleIdentifier })
            }
        }
    }*/
}

struct OptionsView: View {
    @State private var micList = SCContext.getMicrophone()
    
    @AppStorage("frameRate")      private var frameRate: Int = 60
    @AppStorage("videoQuality")   private var videoQuality: Double = 1.0
    @AppStorage("showMouse")      private var showMouse: Bool = true
    @AppStorage("recordMic")      private var recordMic: Bool = false
    @AppStorage("recordWinSound") private var recordWinSound: Bool = true
    @AppStorage("background")     private var background: BackgroundType = .wallpaper
    @AppStorage("highRes")        private var highRes: Int = 2
    @AppStorage("recordHDR")      private var recordHDR: Bool = false
    @AppStorage("micDevice")      private var micDevice: String = "default"

    /// Screen and area recordings show the screen as it is (#83)
    var showsBackground = true
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Resolution")
                    Text("Frame Rate")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $highRes) {
                        Text("High (auto)").tag(2)
                        Text("Normal (1x)").tag(1)
                        //Text("Low (0.5x)").tag(0)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 10)
                    Picker("", selection: $frameRate) {
                        if ![240, 144, 120, 90, 60, 30, 24, 15 ,10].contains(frameRate) {
                            Text("\(frameRate) FPS").tag(frameRate)
                        }
                        Text("240 FPS").tag(240)
                        Text("144 FPS").tag(144)
                        Text("120 FPS").tag(120)
                        Text("90 FPS").tag(90)
                        Text("60 FPS").tag(60)
                        Text("30 FPS").tag(30)
                        Text("24 FPS").tag(24)
                        Text("15 FPS").tag(15)
                        Text("10 FPS").tag(10)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 10)
                }.scaledToFit()
                Divider().frame(height: 50)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quality")
                    if showsBackground { Text("Background") }
                }.padding(.leading, 8)
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $videoQuality) {
                        Text("High").tag(1.0)
                        Text("Medium").tag(0.7)
                        Text("Low").tag(0.3)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 10)
                    if showsBackground {
                        Picker("", selection: $background) {
                            Text("Wallpaper").tag(BackgroundType.wallpaper)
                            if ud.bool(forKey: "withAlpha") { Text("Transparent").tag(BackgroundType.clear) }
                            Text("Black").tag(BackgroundType.black)
                            Text("White").tag(BackgroundType.white)
                            Text("Gray").tag(BackgroundType.gray)
                            Text("Yellow").tag(BackgroundType.yellow)
                            Text("Orange").tag(BackgroundType.orange)
                            Text("Green").tag(BackgroundType.green)
                            Text("Blue").tag(BackgroundType.blue)
                            Text("Red").tag(BackgroundType.red)
                            Text("Custom").tag(BackgroundType.custom)
                        }
                        .buttonStyle(.borderless)
                        .frame(minWidth: 10)
                    }
                }.scaledToFit()
                Divider().frame(height: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(isOn: $recordHDR) {
                        HStack(spacing:0){
                            Image(systemName: "sparkles.square.filled.on.square")
                                .font(.subheadline)
                                .frame(width: 16)
                            Text("Record HDR")
                                .font(.subheadline)
                        }
                    }
                    .fixedSize()
                    .toggleStyle(.checkbox)
                    Toggle(isOn: $showMouse) {
                        HStack(spacing: 0){
                            Image(systemName: "cursorarrow")
                                .font(.subheadline)
                                .frame(width: 16)
                            Text("Record Cursor")
                                .font(.subheadline)
                        }
                    }
                    .fixedSize()
                    .toggleStyle(.checkbox)
                    Toggle(isOn: $recordWinSound) {
                        HStack(spacing: 0){
                            Image(systemName: "speaker.wave.1.fill")
                                .font(.subheadline)
                                .frame(width: 16)
                            Text("App's Audio")
                                .font(.subheadline)
                        }
                    }
                    .fixedSize()
                    .toggleStyle(.checkbox)
                    HStack(spacing: 0) {
                        Toggle(isOn: $recordMic) {
                            Image(systemName: "mic.fill")
                                .font(.subheadline)
                                .frame(width: 16)
                        }
                        .fixedSize()
                        .toggleStyle(.checkbox)
                        .onChange(of: recordMic) {
                            Task { await SCContext.performMicCheck() }
                        }
                        .onAppear{ if micList.isEmpty { recordMic = false } }
                        .disabled(micList.isEmpty)
                        Picker("", selection: $micDevice) {
                            Text("Default".local).tag("default")
                            ForEach(micList, id: \.self) { device in
                                Text(device.localizedName).tag(device.localizedName)
                            }
                        }
                        .disabled(!recordMic)
                        .scaleEffect(0.8)
                        .padding(.leading, -16)
                        .frame(width: 90, height: 12)
                        .onAppear{
                            let list = micList.map({ $0.localizedName })
                            if !list.contains(micDevice) { micDevice = "default" }
                        }
                        Spacer().frame(width: 5)
                    }
                }.padding(.trailing, -17)
            }
        }
    }
}

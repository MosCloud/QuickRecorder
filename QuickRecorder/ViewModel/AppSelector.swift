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
                                        SelectableCard(title: item.applicationName != "" ? item.applicationName : item.bundleIdentifier,
                                                       titleWidth: 112, chosen: selected.contains(item), action: {
                                            if !selected.contains(item) { selected.append(item) } else { selected.removeAll { $0 == item } }
                                        }) {
                                            Image(nsImage: SCContext.getAppIcon(item)!).frame(width: 112, height: 72)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12).padding(.top, 4)
                        }
                    }
                    // Room for the ring and the tick of a chosen card
                    .padding(.top, 8)
                }
            }
            SelectorCapsule(leading: [CapsuleLeading(symbol: "arrow.clockwise", label: "Refresh".local, spins: true, action: { viewModel.updateAppList() })],
                            screen: display?.nsScreen ?? NSScreen.main, showsBackground: true,
                            canStart: selected.count >= 1) {
                startRecording(autoStop: $0)
            }
            Spacer()
        }
        .padding(.top, -5)
        .frame(width: 780, height: 555)
    }

    func startRecording(autoStop: TimeInterval) {
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

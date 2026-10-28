//
//  SelectorParts.swift
//  QuickRecorder
//
//  What the screen, area, window, app and click-to-select pickers share (#23); their capsule is in SelectorCapsule.swift (#79)
//

import SwiftUI
import Combine
import ScreenCaptureKit

/// A screen or window thumbnail over a soft shadow of itself, so light content stands out from the window
struct ShadowedThumbnail: View {
    @Environment(\.colorScheme) private var colorScheme
    let image: NSImage

    var body: some View {
        ZStack {
            if colorScheme == .light {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorMultiply(.black)
                    .blur(radius: 0.5)
            } else {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorMultiply(.black)
                    .colorInvert()
                    .blur(radius: 0.5)
            }
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

/// A tab per display, opening on the one the selector's window is on (the app and window selectors)
struct DisplayTabs<Item, Content: View>: View {
    /// Read when the list is ready, not when the view was made: the list fills in just before
    let items: () -> [SCDisplay: [Item]]
    let isReady: Published<Bool>.Publisher
    let windowTitle: String
    let onShow: (SCDisplay) -> Void
    let onSwitch: () -> Void
    @ViewBuilder let content: (SCDisplay, [Item]) -> Content
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            let displays = sorted(items())
            ForEach(displays, id: \.key) { element in
                let (screen, list) = element
                let index = displays.firstIndex(where: { $0.key == screen }) ?? 0
                content(screen, list)
                    .tag(index)
                    .tabItem { Text(screen.nsScreen?.localizedName ?? ("Display ".local + "\(index)")) }
                    .onAppear { onShow(screen) }
            }
        }
        .frame(height: 445)
        .padding(.horizontal, 10)
        .onChange(of: selectedTab) { onSwitch() }
        .onReceive(isReady) { isReady in
            if isReady {
                let displays = sorted(items())
                if let s = NSApp.windows.first(where: { $0.title == windowTitle })?.screen,
                   let index = displays.firstIndex(where: { $0.key.displayID == s.displayID }) {
                    selectedTab = index
                }
            }
        }
    }

    private func sorted(_ items: [SCDisplay: [Item]]) -> [(key: SCDisplay, value: [Item])] {
        items.sorted(by: { $0.key.displayID < $1.key.displayID })
    }
}

extension AppDelegate {
    /// What a selector's Start does once its windows are closed: count down on `screen`, then record
    func countdownAndRecord(type: String, screen: SCDisplay, windows: [SCWindow]? = nil,
                            applications: [SCRunningApplication]? = nil, autoStop: TimeInterval) {
        createCountdownPanel(screen: screen) {
            SCContext.autoStop = autoStop
            self.prepRecord(type: type, screens: screen, windows: windows, applications: applications)
        }
    }

    /// The corners around an area about to be recorded (global coordinates), far enough out to stay out of it (#97)
    func showAreaOutline(_ area: NSRect) {
        let margin = 2 * AreaMarkStyle.width
        let frame = NSRect(x: Int(area.origin.x - margin),
                           y: Int(area.origin.y - margin),
                           width: Int(area.width + 2 * margin), height: Int(area.height + 2 * margin))
        let window = NSWindow(contentRect: frame, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.title = "Area Overlayer".local
        window.backgroundColor = NSColor.clear
        window.contentView = NSHostingView(rootView: AreaOutline())
        window.orderFront(self)
    }
}

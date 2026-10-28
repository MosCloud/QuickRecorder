//
//  SelectorParts.swift
//  QuickRecorder
//
//  What the screen, area, window, app and click-to-select pickers share (#23)
//

import SwiftUI
import Combine
import ScreenCaptureKit

/// A round icon over its caption, the buttons along the selectors' bars
struct BarButton<Style: ShapeStyle>: View {
    let icon: String
    let style: Style
    let title: LocalizedStringKey
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: size))
                    .foregroundStyle(style)
                Text(title)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
        }).buttonStyle(.plain)
    }
}

/// The end of every selector's bar: the timer that stops the recording after a set number of minutes, and Start.
/// Its two buttons join the bar's own stack.
struct StartControls: View {
    var canStart = true
    /// Starts with the minutes after which to stop, 0 for never
    let start: (_ autoStop: Int) -> Void
    @State private var autoStop = 0
    @State private var isTimerShowing = false

    var body: some View {
        Button(action: {
            isTimerShowing = true
        }, label: {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.blue)
        })
        .buttonStyle(.plain)
        .padding(.top, 42.5)
        .popover(isPresented: $isTimerShowing, arrowEdge: .bottom, content: {
            HStack {
                Text(" Stop after".local)
                TextField("", value: $autoStop, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Stepper("", value: $autoStop)
                    .padding(.leading, -10)
                Text("minutes ".local)
            }
            .fixedSize()
            .padding()
        })
        BarButton(icon: "record.circle.fill", style: .red, title: "Start") { start(autoStop) }
            .disabled(!canStart)
    }
}

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

/// The green tick on a chosen thumbnail
struct SelectionMark: View {
    let selected: Bool
    var size: CGFloat = 27

    var body: some View {
        ZStack {
            Image(systemName: "circle.fill")
                .font(.system(size: size * 31 / 27))
                .foregroundStyle(.white)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size))
                .foregroundStyle(.green)
        }.opacity(selected ? 1.0 : 0.0)
    }
}

/// The blue behind a chosen thumbnail
struct SelectionBackground: View {
    let selected: Bool
    /// Above zero, an unchosen card still takes clicks across its whole area
    var idle = 0.0

    var body: some View {
        Rectangle()
            .foregroundStyle(.blue)
            .cornerRadius(5)
            .opacity(selected ? 0.2 : idle)
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
                            applications: [SCRunningApplication]? = nil, autoStop: Int) {
        createCountdownPanel(screen: screen) {
            SCContext.autoStop = autoStop
            self.prepRecord(type: type, screens: screen, windows: windows, applications: applications)
        }
    }

    /// The dashed outline around an area about to be recorded (global coordinates), `margin` points outside it
    func showAreaOutline(_ area: NSRect, margin: CGFloat) {
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
        window.contentView = NSHostingView(rootView: DashWindow())
        window.orderFront(self)
    }
}

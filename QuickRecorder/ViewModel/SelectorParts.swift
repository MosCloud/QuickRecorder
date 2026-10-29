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

/// Esc in a picker goes one layer at a time (#153): a bubble or the colour window takes the first one (#95), then the
/// choice itself, and only when nothing is chosen does the picker close and the main panel come back.
///
/// The monitor follows the picker's own window (#155): it only handles Esc delivered to that window, and it is removed
/// when the window closes. SwiftUI does not call `onDisappear` for a window that is merely closed, so a monitor removed
/// there outlives the picker and eats the next Esc anywhere in the app.
struct EscapeClearsSelection: ViewModifier {
    let canClear: () -> Bool
    let clear: () -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content.background(
            WindowAccessor(onWindowOpen: { window in watch(window) },
                           onWindowClose: { stopWatching() })
        )
    }

    private func watch(_ window: NSWindow?) {
        stopWatching()
        guard let window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53 else { return event }
            let action = MainActor.assumeIsolated {
                PickerEscape.action(ownWindow: event.window === window,
                                    bubbleOpen: CapsuleBubbles.shared.open != nil,
                                    colourWindowOpen: ColorWindow.shared.isOpen,
                                    hasChoice: canClear(),
                                    isRepeat: event.isARepeat)
            }
            switch action {
            case .passOn:        return event
            case .closePicker:   return event
            case .swallowRepeat: return nil
            case .clearChoice:
                MainActor.assumeIsolated { clear() }
                return nil
            }
        }
    }

    private func stopWatching() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

extension View {
    /// Esc clears what's chosen in a picker before it leaves (#153)
    func escapeClearsSelection<Element>(_ selection: Binding<[Element]>) -> some View {
        modifier(EscapeClearsSelection(canClear: { !selection.wrappedValue.isEmpty },
                                       clear: { selection.wrappedValue.removeAll() }))
    }

    func escapeClearsSelection<Element>(_ selection: Binding<Element?>) -> some View {
        modifier(EscapeClearsSelection(canClear: { selection.wrappedValue != nil },
                                       clear: { selection.wrappedValue = nil }))
    }
}

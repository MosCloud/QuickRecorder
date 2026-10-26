//
//  SettingsView.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/19.
//

import SwiftUI
import ServiceManagement
import KeyboardShortcuts
import Carbon.HIToolbox

struct SettingsView: View {
    @State private var selectedItem: String? = "General"
    
    var body: some View {
        NavigationView {
            List(selection: $selectedItem) {
                Label("General", image: "gear").tag("General")
                Label("Recorder", image: "record").tag("Recorder")
                Label("Output", image: "film").tag("Output")
                Label("Hotkey", image: "hotkey").tag("Hotkey")
                Label("Blocklist", image: "blacklist").tag("Blocklist")
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
            detail
        }.frame(width: 600, height: 512)
    }

    @ViewBuilder private var detail: some View {
        switch selectedItem {
        case "Recorder": ScrollView { RecorderView() } // Taller than the window since the recording controls group
        case "Output": OutputView()
        case "Hotkey": HotkeyView()
        case "Blocklist": BlocklistView()
        default: GeneralView()
        }
    }
}

struct GeneralView: View {
    @AppStorage("countdown") private var countdown: Int = 0
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = false
    
    @State private var launchAtLogin = false

    var body: some View {
        SForm {
            SGroupBox(label: "Startup") {
                SToggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        }catch{
                            print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                        }
                    }
                SDivider()
                SToggle("Show QuickRecorder on Dock", isOn: $showOnDock)
                    //.disabled(!showMenubar)
                SDivider()
                SToggle("Show QuickRecorder on Menu Bar", isOn: $showMenubar)
                    //.disabled(!showOnDock)
            }
            VStack(spacing: 8) {
                if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("QuickRecorder v\(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear{ launchAtLogin = (SMAppService.mainApp.status == .enabled) }
        .onChange(of: showMenubar) { updateStatusBar() }
        .onChange(of: showOnDock) { _, newValue in
            if !newValue {
                NSApp.setActivationPolicy(.accessory)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
}

struct RecorderView: View {
    @AppStorage("countdown")        private var countdown: Int = 0
    @AppStorage("highlightMouse")   private var highlightMouse: Bool = false
    @AppStorage("includeMenuBar")   private var includeMenuBar: Bool = true
    @AppStorage("hideDesktopFiles") private var hideDesktopFiles: Bool = false
    @AppStorage("trimAfterRecord")  private var trimAfterRecord: Bool = false
    @AppStorage("controlsMenuBar")  private var controlsMenuBar: Bool = true
    @AppStorage("controlsCapsule")  private var controlsCapsule: Bool = true
    @AppStorage("capsuleMaterial")  private var capsuleMaterial: CapsuleMaterial = .glass
    @AppStorage("capsuleIdleOpacity") private var capsuleIdleOpacity: Double = 0.5
    @AppStorage("hideSelf")         private var hideSelf: Bool = true
    @AppStorage("preventSleep")     private var preventSleep: Bool = true
    @AppStorage("showPreview")      private var showPreview: Bool = true
    @AppStorage("hideCCenter")      private var hideCCenter: Bool = false
    
    @State private var userColor: Color = Color.black

    var body: some View {
        SForm(spacing: 10) {
            SGroupBox(label: "Recorder") {
                SSteper("Delay Before Recording", value: $countdown, min: 0, max: 99)
                SDivider()
                SItem(label: "Custom Background Color") {
                    ColorGridPicker(selection: $userColor)
                        .onChange(of: userColor) { _, userColor in ud.setColor(userColor, forKey: "userColor") }
                }
            }
            SGroupBox(label: "Recording Controls") {
                // At least one stays on: the one left on can't be switched off
                SToggle("Menu Bar Timer and Menu", isOn: $controlsMenuBar)
                    .disabled(controlsMenuBar && !controlsCapsule)
                SDivider()
                SToggle("Floating Capsule", isOn: $controlsCapsule,
                        tips: "At least one of them stays on. The capsule hangs below the notch and never appears in recordings.")
                    .disabled(controlsCapsule && !controlsMenuBar)
                SDivider()
                SPicker("Capsule Material", selection: $capsuleMaterial) {
                    Text("Liquid Glass").tag(CapsuleMaterial.glass)
                    Text("Frosted Glass").tag(CapsuleMaterial.blur)
                    Text("Black").tag(CapsuleMaterial.black)
                }.disabled(!controlsCapsule)
                SDivider()
                SItem(label: "Opacity When Idle") {
                    Slider(value: $capsuleIdleOpacity, in: 0.1...1, step: 0.05).frame(width: 150)
                    Text("\(Int((capsuleIdleOpacity * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }.disabled(!controlsCapsule)
            }
            .onChange(of: controlsMenuBar) { updateStatusBar() }
            .onChange(of: controlsCapsule) { updateStatusBar() }
            SGroupBox(label: "Recording Behavior") {
                SToggle("Prevent Mac from sleeping while recording", isOn: $preventSleep)
                SDivider()
                SToggle("Show floating preview after recording", isOn: $showPreview)
                SDivider()
                SToggle("Open video trimmer after recording", isOn: $trimAfterRecord)
            }
            SGroupBox(label: "Captured Content") {
                SToggle("Exclude QuickRecorder itself", isOn: $hideSelf)
                SDivider()
                SToggle("Include Menu Bar in Recording", isOn: $includeMenuBar)
                SDivider()
                SToggle("Hide Control Center Icons", isOn: $hideCCenter, tips: "Hide the clock, Wi-Fi, bluetooth, volume and other system icons in the menu bar.")
                SDivider()
                SToggle("Highlight the Mouse Cursor", isOn: $highlightMouse, tips: "Not available for \"Single Window Capture\"")
                SDivider()
                SToggle("Exclude Files on Desktop", isOn: $hideDesktopFiles, tips: "If enabled, all files on the Desktop will be hidden from the video when recording.")
            }
        }.onAppear{ userColor = ud.color(forKey: "userColor") ?? Color.black }
    }
}

struct OutputView: View {
    @AppStorage("encoder")          private var encoder: Encoder = .h265
    @AppStorage("videoFormat")      private var videoFormat: VideoFormat = .mp4
    @AppStorage("audioFormat")      private var audioFormat: AudioFormat = .aac
    @AppStorage("audioQuality")     private var audioQuality: AudioQuality = .high
    @AppStorage("background")       private var background: BackgroundType = .wallpaper
    @AppStorage("remuxAudio")       private var remuxAudio: Bool = true
    @AppStorage("withAlpha")        private var withAlpha: Bool = false
    @AppStorage("saveDirectory")    private var saveDirectory: String?

    var body: some View {
        SForm(spacing: 30) {
            SGroupBox(label: "Audio") {
                SPicker("Quality", selection: $audioQuality) {
                    if audioFormat == .alac {
                        Text("Lossless").tag(audioQuality)
                    }
                    Text("Normal - 128Kbps").tag(AudioQuality.normal)
                    Text("Good - 192Kbps").tag(AudioQuality.good)
                    Text("High - 256Kbps").tag(AudioQuality.high)
                    Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                }.disabled(audioFormat == .alac)
                SDivider()
                SPicker("Format", selection: $audioFormat) {
                    Text("AAC").tag(AudioFormat.aac)
                    Text("ALAC (Lossless)").tag(AudioFormat.alac)
                }
                SDivider()
                SToggle("Record Microphone to Main Track", isOn: $remuxAudio)
            }
            SGroupBox(label: "Video") {
                SPicker("Format", selection: $videoFormat) {
                    Text("MOV").tag(VideoFormat.mov)
                    Text("MP4").tag(VideoFormat.mp4)
                }.disabled(withAlpha)
                SDivider()
                SPicker("Encoder", selection: $encoder) {
                    Text("H.264").tag(Encoder.h264)
                    Text("H.265").tag(Encoder.h265)
                }.disabled(withAlpha)
                SDivider()
                SToggle("Recording with Alpha Channel", isOn: $withAlpha,
                        tips: "Records with HEVC with Alpha, so transparent areas stay transparent in the video.\n\n• Turning it on fixes the encoder to H.265 and the format to MOV.\n• When recording an application, the Background menu then offers \"Transparent\": everything outside the selected apps' windows is transparent.\n• A full screen or screen area recording has no transparent areas, so it makes no difference there.\n• The transparency shows in apps that support transparent video, such as Final Cut Pro, Motion and Keynote. Most players and video sites don't.")
            }
            SGroupBox(label: "Save") {
                SItem(label: "Output Folder") {
                    Text(String(format: "Currently set to \"%@\"".local, saveDirectory!.lastPathComponent))
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Button("Select...", action: { updateOutputDirectory() })
                }
            }
        }.onChange(of: withAlpha) { _, alpha in
            if alpha {
                encoder = Encoder.h265; videoFormat = VideoFormat.mov
            } else {
                if background == .clear { background = .wallpaper }
            }
        }
    }
    
    func updateOutputDirectory() { // todo: re-sandbox
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = false
        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            if let path = openPanel.urls.first?.path { saveDirectory = path }
        }
    }
}

struct HotkeyView: View {
    var body: some View {
        SForm(spacing: 10) {
            SGroupBox(label: "Hotkey") {
                SItem(label: "Open Main Panel") { HotkeyRecorder(name: .showPanel) }
            }
            SGroupBox {
                SItem(label: "Stop Recording") { HotkeyRecorder(name: .stop) }
                SDivider()
                SItem(label: "Pause / Resume") { HotkeyRecorder(name: .pauseResume) }
            }
            SGroupBox {
                SItem(label: "Record System Audio") { HotkeyRecorder(name: .startWithAudio) }
                SDivider()
                SItem(label: "Record Current Screen") { HotkeyRecorder(name: .startWithScreen) }
                SDivider()
                SItem(label: "Record Topmost Window") { HotkeyRecorder(name: .startWithWindow) }
                SDivider()
                SItem(label: "Select Area to Record") { HotkeyRecorder(name: .startWithArea) }
            }
            SGroupBox {
                SItem(label: "Save Current Frame") { HotkeyRecorder(name: .saveFrame) }
            }
            HStack {
                Spacer()
                Button("Restore Defaults") { KeyboardShortcuts.reset(KeyboardShortcuts.Name.labelled.map(\.name)) }
            }
        }
    }
}

struct BlocklistView: View {
    var body: some View {
        SForm(spacing: 0, noSpacer: true) {
            SGroupBox(label: "Blocklist") {
                    BundleSelector()
                    Text("These apps will be excluded when recording \"Screen\" or \"Screen Area\"\nBut if the app is launched after the recording starts, it cannot be excluded.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.secondary)
            }
        }
    }
}

extension UserDefaults {
    func setColor(_ color: Color?, forKey key: String) {
        guard let color = color else {
            removeObject(forKey: key)
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: NSColor(color), requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            print("Error archiving color:", error)
        }
    }
    
    func color(forKey key: String) -> Color? {
        guard let data = data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return Color(nsColor)
    }
    
    func cgColor(forKey key: String) -> CGColor? {
        guard let data = data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return nsColor.cgColor
    }
}

// Defaults are ⌃⌥⌘ plus a letter to remember them by; no system shortcut uses these
extension KeyboardShortcuts.Name {
    static let startWithAudio = Self("startWithAudio", initial: .init(.u, modifiers: [.control, .option, .command]))
    static let startWithScreen = Self("startWithScreen", initial: .init(.s, modifiers: [.control, .option, .command]))
    static let startWithWindow = Self("startWithWindow", initial: .init(.w, modifiers: [.control, .option, .command]))
    static let startWithArea = Self("startWithArea", initial: .init(.a, modifiers: [.control, .option, .command]))
    static let saveFrame = Self("saveFrame", initial: .init(.f, modifiers: [.control, .option, .command]))
    static let pauseResume = Self("pauseResume", initial: .init(.p, modifiers: [.control, .option, .command]))
    static let stop = Self("stop", initial: .init(.x, modifiers: [.control, .option, .command]))
    static let showPanel = Self("showPanel", initial: .init(.r, modifiers: [.control, .option, .command]))

    /// Once per version of the defaults, replace every hotkey with its default: version 1 brings in the ⌃⌥⌘ set
    /// and takes back the plain ⌘ ones that stopped other apps' shortcuts working.
    @MainActor static func applyDefaultsOnce() {
        let version = 1
        guard ud.integer(forKey: "hotkeyDefaultsVersion") < version else { return }
        KeyboardShortcuts.reset(labelled.map(\.name))
        ud.removeObject(forKey: "KeyboardShortcuts_screenMagnifier") // the magnifier is gone
        ud.set(version, forKey: "hotkeyDefaultsVersion")
    }
}

extension KeyboardShortcuts.Name {
    /// Every global hotkey, with the label the settings show for it.
    static let labelled: [(name: Self, label: String)] = [
        (.showPanel, "Open Main Panel"), (.stop, "Stop Recording"), (.pauseResume, "Pause / Resume"),
        (.startWithAudio, "Record System Audio"), (.startWithScreen, "Record Current Screen"),
        (.startWithWindow, "Record Topmost Window"), (.startWithArea, "Select Area to Record"), (.saveFrame, "Save Current Frame"),
    ]
}

/// A hotkey recorder that refuses a shortcut another action already has, or one other apps rely on.
private struct HotkeyRecorder: View {
    let name: KeyboardShortcuts.Name

    var body: some View {
        KeyboardShortcuts.Recorder("", name: name)
            .shortcutValidation { shortcut in
                let others = KeyboardShortcuts.Name.labelled.compactMap { other in
                    other.name == name ? nil : other.name.shortcut.map { (action: other.label.local, hotkey: $0.hotkey) }
                }
                switch HotkeyCheck.verdict(for: shortcut.hotkey, others: others) {
                case .allowed:
                    return .allow
                case .usedBy(let action):
                    return .disallow(reason: String(format: "This shortcut is already used by “%@”.".local, action))
                case .commonInApps:
                    return .disallow(reason: "⌘ (or ⇧⌘) with a letter or number is a shortcut other apps use, such as ⌘S to save. As a global shortcut it would stop working in every app while QuickRecorder runs. Add ⌃ or ⌥ to it.".local)
                }
            }
    }
}

private extension KeyboardShortcuts.Shortcut {
    /// Letter and digit keys of the US layout, by Carbon key code
    static let characterKeys: Set<Int> = [
        kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I,
        kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R,
        kVK_ANSI_S, kVK_ANSI_T, kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y, kVK_ANSI_Z,
        kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
    ]

    var hotkey: Hotkey {
        var mods = HotkeyModifiers()
        if modifiers.contains(.command) { mods.insert(.command) }
        if modifiers.contains(.option) { mods.insert(.option) }
        if modifiers.contains(.control) { mods.insert(.control) }
        if modifiers.contains(.shift) { mods.insert(.shift) }
        return Hotkey(keyCode: carbonKeyCode, modifiers: mods, isCharacterKey: Self.characterKeys.contains(carbonKeyCode))
    }
}

extension AppDelegate {
    @objc func setLoginItem(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            if sender.state == .off { try SMAppService.mainApp.unregister() }
        }catch{
            print("Failed to \(sender.state == .on ? "enable" : "disable") launch at login: \(error.localizedDescription)")
        }
    }
}

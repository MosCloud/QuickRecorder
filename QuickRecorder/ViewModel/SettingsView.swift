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

/// The five pages as tabs in the settings window's toolbar, in macOS 26's design language (#81)
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            RecorderSettingsView()
                .tabItem { Label("Recorder", systemImage: "record.circle") }
            OutputSettingsView()
                .tabItem { Label("Output", systemImage: "film") }
            HotkeySettingsView()
                .tabItem { Label("Hotkey", systemImage: "command") }
            BlocklistSettingsView()
                .tabItem { Label("Blocklist", systemImage: "hand.raised") }
        }
    }
}

// MARK: - Rows

/// The explanation belongs to its setting: an ⓘ beside the label, opened over the page
private struct SettingsInfo: View {
    let text: String
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More Info".local)
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(text.local).font(.callout).padding(12)
                .frame(width: 300, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A switch whose label can carry its explanation
private struct InfoToggle: View {
    let title: LocalizedStringKey
    var info: String?
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, info: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.info = info
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 5) {
                Text(title)
                if let info { SettingsInfo(text: info) }
            }
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @AppStorage("showOnDock")    private var showOnDock: Bool = true
    @AppStorage("showMenubar")   private var showMenubar: Bool = false
    @AppStorage("capsuleMaterial") private var material: PanelMaterial = .glass
    @AppStorage("mainPanelOnTop") private var mainPanelOnTop: Bool = true

    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Toggle("Show QuickRecorder on Dock", isOn: $showOnDock)
                Toggle("Show QuickRecorder on Menu Bar", isOn: $showMenubar)
            }
            Section("Appearance") {
                Picker("Panel and Capsule Material", selection: $material) {
                    Text("Liquid Glass").tag(PanelMaterial.glass)
                    Text("Frosted Glass").tag(PanelMaterial.blur)
                    Text("Black").tag(PanelMaterial.black)
                }
            }
            Section("Main Panel") {
                InfoToggle("Keep Main Panel on Top", isOn: $mainPanelOnTop)
            }
            Section {
            } footer: {
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("QuickRecorder v\(version)").frame(maxWidth: .infinity).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 390)
        .onAppear { launchAtLogin = (SMAppService.mainApp.status == .enabled) }
        .onChange(of: launchAtLogin) { _, on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                print("Failed to \(on ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
        .onChange(of: showMenubar) { updateStatusBar() }
        .onChange(of: showOnDock) { _, on in
            if !on {
                NSApp.setActivationPolicy(.accessory)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
        // The switch changes a panel that may already be up, without closing and opening it (#111)
        .onChange(of: mainPanelOnTop) { _, on in
            AppDelegate.shared.mainPanelWindow?.level = on ? .floating : .normal
        }
    }
}

// MARK: - Recorder

struct RecorderSettingsView: View {
    @AppStorage("countdown")        private var countdown: Int = 0
    @AppStorage("highlightMouse")   private var highlightMouse: Bool = false
    @AppStorage("includeMenuBar")   private var includeMenuBar: Bool = true
    @AppStorage("hideDesktopFiles") private var hideDesktopFiles: Bool = false
    @AppStorage("trimAfterRecord")  private var trimAfterRecord: Bool = false
    @AppStorage("controlsMenuBar")  private var controlsMenuBar: Bool = true
    @AppStorage("controlsCapsule")  private var controlsCapsule: Bool = true
    @AppStorage("capsuleIdleOpacity") private var capsuleIdleOpacity: Double = 0.5
    @AppStorage("hideSelf")         private var hideSelf: Bool = true
    @AppStorage("preventSleep")     private var preventSleep: Bool = true
    @AppStorage("showPreview")      private var showPreview: Bool = true
    @AppStorage("hideCCenter")      private var hideCCenter: Bool = false

    var body: some View {
        Form {
            Section("Recorder") {
                LabeledContent("Delay Before Recording") {
                    HStack(spacing: 8) {
                        Text("\(countdown)").monospacedDigit()
                        Stepper("", value: $countdown, in: 0...99).labelsHidden()
                    }
                }
            }
            Section("Recording Controls") {
                // At least one stays on: the one left on can't be switched off
                InfoToggle("Menu Bar Timer and Menu", isOn: $controlsMenuBar)
                    .disabled(controlsMenuBar && !controlsCapsule)
                InfoToggle("Floating Capsule",
                           info: "At least one of them stays on. The capsule hangs below the notch and never appears in recordings.",
                           isOn: $controlsCapsule)
                    .disabled(controlsCapsule && !controlsMenuBar)
                LabeledContent("Opacity When Idle") {
                    HStack(spacing: 8) {
                        Slider(value: $capsuleIdleOpacity, in: 0.1...1, step: 0.05).frame(width: 150)
                        Text("\(Int((capsuleIdleOpacity * 100).rounded()))%").monospacedDigit().frame(width: 36, alignment: .trailing)
                    }
                }
                .disabled(!controlsCapsule)
            }
            .onChange(of: controlsMenuBar) { updateStatusBar() }
            .onChange(of: controlsCapsule) { updateStatusBar() }
            Section("Recording Behavior") {
                InfoToggle("Prevent Mac from sleeping while recording", isOn: $preventSleep)
                InfoToggle("Show floating preview after recording", isOn: $showPreview)
                InfoToggle("Open video trimmer after recording", isOn: $trimAfterRecord)
            }
            Section("Captured Content") {
                InfoToggle("Exclude QuickRecorder itself", isOn: $hideSelf)
                InfoToggle("Include Menu Bar in Recording", isOn: $includeMenuBar)
                InfoToggle("Hide Control Center Icons",
                           info: "Hide the clock, Wi-Fi, bluetooth, volume and other system icons in the menu bar.",
                           isOn: $hideCCenter)
                InfoToggle("Highlight the Mouse Cursor", info: "Not available for \"Single Window Capture\"", isOn: $highlightMouse)
                InfoToggle("Exclude Files on Desktop",
                           info: "If enabled, all files on the Desktop will be hidden from the video when recording.",
                           isOn: $hideDesktopFiles)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 670)
    }
}

// MARK: - Output

struct OutputSettingsView: View {
    @AppStorage("encoder")          private var encoder: Encoder = .h265
    @AppStorage("videoFormat")      private var videoFormat: VideoFormat = .mp4
    @AppStorage("audioFormat")      private var audioFormat: AudioFormat = .aac
    @AppStorage("audioQuality")     private var audioQuality: AudioQuality = .high
    @AppStorage("background")       private var background: BackgroundType = .wallpaper
    @AppStorage("remuxAudio")       private var remuxAudio: Bool = true
    @AppStorage("withAlpha")        private var withAlpha: Bool = false
    @AppStorage("saveDirectory")    private var saveDirectory: String?

    var body: some View {
        Form {
            Section("Audio") {
                Picker("Quality", selection: $audioQuality) {
                    if audioFormat == .alac {
                        Text("Lossless").tag(audioQuality)
                    }
                    Text("Normal - 128Kbps").tag(AudioQuality.normal)
                    Text("Good - 192Kbps").tag(AudioQuality.good)
                    Text("High - 256Kbps").tag(AudioQuality.high)
                    Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                }
                .disabled(audioFormat == .alac)
                Picker("Format", selection: $audioFormat) {
                    Text("AAC").tag(AudioFormat.aac)
                    Text("ALAC (Lossless)").tag(AudioFormat.alac)
                }
                InfoToggle("Record Microphone to Main Track", isOn: $remuxAudio)
            }
            Section("Video") {
                Picker("Format", selection: $videoFormat) {
                    Text("MOV").tag(VideoFormat.mov)
                    Text("MP4").tag(VideoFormat.mp4)
                }
                .disabled(withAlpha)
                Picker("Encoder", selection: $encoder) {
                    Text("H.264").tag(Encoder.h264)
                    Text("H.265").tag(Encoder.h265)
                }
                .disabled(withAlpha)
                InfoToggle("Recording with Alpha Channel",
                           info: "Records with HEVC with Alpha, so transparent areas stay transparent in the video.\n\n• Turning it on fixes the encoder to H.265 and the format to MOV.\n• When recording an application, the Background menu then offers \"Transparent\": everything outside the selected apps' windows is transparent.\n• A full screen or screen area recording has no transparent areas, so it makes no difference there.\n• The transparency shows in apps that support transparent video, such as Final Cut Pro, Motion and Keynote. Most players and video sites don't.",
                           isOn: $withAlpha)
            }
            Section("Save") {
                LabeledContent("Output Folder") {
                    HStack(spacing: 8) {
                        Text(saveDirectory?.lastPathComponent ?? "")
                            .lineLimit(1).truncationMode(.tail).foregroundStyle(.secondary)
                        Button("Select...") { updateOutputDirectory() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 435)
        .onChange(of: withAlpha) { _, alpha in
            if alpha {
                encoder = .h265
                videoFormat = .mov
            } else if background == .clear {
                background = .wallpaper
            }
        }
    }

    private func updateOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = false
        if openPanel.runModal() == .OK, let path = openPanel.urls.first?.path { saveDirectory = path }
    }
}

// MARK: - Hotkeys

struct HotkeySettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Open Main Panel") { HotkeyRecorder(name: .showPanel) }
            }
            Section("Recording") {
                LabeledContent("Stop Recording") { HotkeyRecorder(name: .stop) }
                LabeledContent("Pause / Resume") { HotkeyRecorder(name: .pauseResume) }
            }
            Section("Start Recording") {
                LabeledContent("Record System Audio") { HotkeyRecorder(name: .startWithAudio) }
                LabeledContent("Record Current Screen") { HotkeyRecorder(name: .startWithScreen) }
                LabeledContent("Record Topmost Window") { HotkeyRecorder(name: .startWithWindow) }
                LabeledContent("Select Area to Record") { HotkeyRecorder(name: .startWithArea) }
            }
            Section {
                LabeledContent("Save Current Frame") { HotkeyRecorder(name: .saveFrame) }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Restore Defaults") { KeyboardShortcuts.reset(KeyboardShortcuts.Name.labelled.map(\.name)) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 585)
    }
}

// MARK: - Blocklist

struct BlocklistSettingsView: View {
    var body: some View {
        Form {
            Section {
                BundleSelector()
                    .frame(height: 280)
            } header: {
                Text("Blocklist")
            } footer: {
                Text("These apps will be excluded when recording \"Screen\" or \"Screen Area\"\nBut if the app is launched after the recording starts, it cannot be excluded.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 410)
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

//
//  SCContext.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import AVFAudio
import AVFoundation
import os
import Foundation
import ScreenCaptureKit
import UserNotifications
import SwiftUI

class SCContext {
    static var trimingList = [URL]()
    static var firstFrame: CMSampleBuffer?
    static var autoStop = 0
    static var recordCam = ""
    static var recordDevice = ""
    static var captureSession: AVCaptureSession!
    static var previewSession: AVCaptureSession!
    static var frameCache: CMSampleBuffer?
    static var filter: SCContentFilter?
    static var saveFrame = false
    static var isPaused = false
    static var isResume = false
    static var isSkipFrame = false
    static var lastPTS: CMTime?
    static var timeOffset = CMTimeMake(value: 0, timescale: 0)
    static var screenArea: NSRect?
    static let audioEngine = AVAudioEngine()
    /// Restarts the microphone when the audio configuration changes during a recording; nil otherwise
    static var micConfigObserver: NSObjectProtocol?
    static var backgroundColor: CGColor = CGColor.black
    static var filePath: String!
    /// Where the recording at `filePath` is mixed to when it ends, its microphone written on a track of its own; nil when there is nothing to mix (#6)
    static var mixedOutput: URL?
    /// Frames and system audio arrive on these, one at a time, so that stopping can wait for what's already on its way
    static let videoQueue = DispatchQueue(label: "QuickRecorder.video")
    static let audioQueue = DispatchQueue(label: "QuickRecorder.audio")
    static let log = Logger(subsystem: "com.lihaoyun6.QuickRecorder", category: "recording")
    private static var recordedAppsObserver: NSObjectProtocol?
    /// The microphone setting a script changed for one recording, to put back when it's over (#72)
    static var recordMicAfterRecording: Bool?
    /// Mixing that runs on after a recording stops: quitting waits for it, or the recording is left in its parts (#71)
    static let finishing = DispatchGroup()
    static var filePath1: String!
    static var filePath2: String!
    static var audioFile: AVAudioFile?
    static var vW: AVAssetWriter!
    static var vwInput, awInput, micInput: AVAssetWriterInput!
    /// When the first frame (or audio sample) was written; nil until then. Gates the capture callbacks.
    static var startTime: Date?
    /// The recording length the controls show. Only touched on the main thread.
    static var clock = RecordingClock()
    /// The capsule's window, which every recording leaves out.
    static var controlWindowID: CGWindowID?
    static var stream: SCStream!
    static var screen: SCDisplay?
    static var window: [SCWindow]?
    static var application: [SCRunningApplication]?
    static var streamType: StreamType?
    static var availableContent: SCShareableContent?
    static let excludedApps = ["", "com.apple.dock", "com.apple.screencaptureui", "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.systemuiserver", "com.apple.WindowManager", "dev.mnpn.Azayaka", "com.gaosun.eul", "com.pointum.hazeover", "net.matthewpalmer.Vanilla", "com.dwarvesv.minimalbar", "com.bjango.istatmenus.status"]
    
    static func updateAvailableContentSync() -> SCShareableContent? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: SCShareableContent? = nil

        updateAvailableContent { content in
            result = content
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }
    
    private static func updateAvailableContent(completion: @escaping (SCShareableContent?) -> Void) {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            if let error = error {
                // Not asked again: retrying every second, for as long as the app ran, asked macOS each time (#5).
                // macOS shows its own prompt; starting a recording explains the rest
                log.error("Couldn't fetch the screen's content: \(error.localizedDescription, privacy: .public)")
                completion(nil)
                return
            }

            availableContent = content
            if let displays = content?.displays, !displays.isEmpty {
                completion(content) // 返回成功获取的 content
            } else {
                print("There needs to be at least one display connected!".local)
                completion(nil) // 如果没有显示器连接，则返回 nil
            }
        }
    }
    
    static func updateAvailableContent(completion: @escaping () -> Void) {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            if let error = error {
                switch error {
                case SCStreamError.userDeclined: requestPermissions()
                default: print("Error: failed to fetch available content: ".local, error.localizedDescription)
                }
                return
            }
            availableContent = content
            assert(availableContent?.displays.isEmpty != nil, "There needs to be at least one display connected!".local)
            completion()
        }
    }
    
    /// The capsule's window, so recordings never show it, whatever "Exclude QuickRecorder itself" says.
    static func getControlWindows() -> [SCWindow] {
        guard let id = controlWindowID else { return [] }
        return windows(withIDs: [id])
    }

    /// The overlays meant to be recorded: the camera and iPhone overlays and the highlighted pointer. With QuickRecorder
    /// left out of a recording, they come back in as exceptions (#13).
    static func getOverlayWindows() -> [SCWindow] {
        windows(withIDs: [mousePointer, camWindow, deviceWindow].filter { $0.windowNumber > 0 }.map { CGWindowID($0.windowNumber) })
    }

    private static func windows(withIDs ids: [CGWindowID]) -> [SCWindow] {
        let found = availableContent?.windows.filter { ids.contains($0.windowID) } ?? []
        guard found.count < ids.count else { return found }
        // The snapshot can predate a window, or list on-screen windows only (the one taken at launch): fetch a full list
        let semaphore = DispatchSemaphore(value: 0)
        var windows = [SCWindow]()
        fetchAllWindows { all in
            windows = all.filter { ids.contains($0.windowID) }
            semaphore.signal()
        }
        semaphore.wait()
        return windows
    }

    private static func fetchAllWindows(completion: @escaping ([SCWindow]) -> Void) {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, _ in
            completion(content?.windows ?? [])
        }
    }

    static func getSelf() -> SCRunningApplication? {
        return SCContext.availableContent!.applications.first(where: { Bundle.main.bundleIdentifier == $0.bundleIdentifier })
    }
    
    static func getSelfWindows() -> [SCWindow]? {
        return SCContext.availableContent!.windows.filter( {
            guard let title = $0.title else { return false }
            return $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
            && title != "Mouse Pointer".local
            && title != "Camera Overlayer".local
            && title != "iDevice Overlayer".local
        })
    }
    
    static func getApps(isOnScreen: Bool = true, hideSelf: Bool = true) -> [SCRunningApplication] {
        var apps = [SCRunningApplication]()
        for app in getWindows(isOnScreen: isOnScreen, hideSelf: hideSelf).map({ $0.owningApplication }) {
            if !apps.contains(app!) { apps.append(app!) }
        }
        if hideSelf && ud.bool(forKey: "hideSelf") { apps = apps.filter({$0.bundleIdentifier != Bundle.main.bundleIdentifier}) }
        return apps
    }
    
    static func getWindows(isOnScreen: Bool = true, hideSelf: Bool = true) -> [SCWindow] {
        var windows = [SCWindow]()
        windows = availableContent!.windows.filter {
            guard let app =  $0.owningApplication,
                  let title = $0.title else {//, !title.isEmpty else {
                return false
            }
            return !excludedApps.contains(app.bundleIdentifier)
            && !title.contains("Item-0")
            && title != "Window"
            && $0.frame.width > 40
            && $0.frame.height > 40
        }
        if isOnScreen { windows = windows.filter({$0.isOnScreen == true}) }
        if hideSelf && ud.bool(forKey: "hideSelf") { windows = windows.filter({$0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier}) }
        return windows
    }
    
    static func getAppIcon(_ app: SCRunningApplication) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 69, height: 69)
            return icon
        }
        let icon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "blank icon")
        icon!.size = NSSize(width: 69, height: 69)
        return icon
    }
    
    static func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screenWithMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
        return screenWithMouse
    }
    
    static func getSCDisplayWithMouse() -> SCDisplay? {
        if let displays = availableContent?.displays {
            for display in displays {
                if let currentDisplayID = getScreenWithMouse()?.displayID {
                    if display.displayID == currentDisplayID {
                        return display
                    }
                }
            }
        }
        return nil
    }
    
    /// Where a new recording or captured frame goes, without its extension
    static func getFilePath(_ kind: RecordingName.Kind) -> String {
        RecordingName.path(directory: ud.string(forKey: "saveDirectory")!, kind: kind, date: Date())
    }
    
    static func updateAudioSettings(format: String = ud.string(forKey: "audioFormat") ?? "", rate: Int = 48000) -> [String : Any] {
        AudioSettings.make(format: format, sampleRate: rate, qualityKbps: ud.integer(forKey: "audioQuality"))
    }
    
    static func getBackgroundColor() -> CGColor {
        guard let color = ud.string(forKey: "background") else { return CGColor.black  }
        if color == BackgroundType.wallpaper.rawValue { return CGColor.black }
        switch color {
            case "clear": backgroundColor = CGColor.clear
            case "black": backgroundColor = CGColor.black
            case "white": backgroundColor = CGColor.white
            case "gray": backgroundColor = NSColor.systemGray.cgColor
            case "yellow": backgroundColor = NSColor.systemYellow.cgColor
            case "orange": backgroundColor = NSColor.systemOrange.cgColor
            case "green": backgroundColor = NSColor.systemGreen.cgColor
            case "blue": backgroundColor = NSColor.systemBlue.cgColor
            case "red": backgroundColor = NSColor.systemRed.cgColor
            default: backgroundColor = ud.cgColor(forKey: "userColor") ?? CGColor.black
        }
        return backgroundColor
    }
    
    static func performMicCheck() async {
        guard ud.bool(forKey: "recordMic") == true else { return }
        if await AVCaptureDevice.requestAccess(for: .audio) { return }

        ud.setValue(false, forKey: "recordMic")
        DispatchQueue.main.async {
            let alert = createAlert(title: "Permission Required",
                                                       message: "QuickRecorder needs permission to record your microphone.",
                                                       button1: "Open Settings",
                                                       button2: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
        }
    }
    
    /// Starting a recording was refused the screen's content: says what it takes, and stays open (#5).
    /// It used to quit whichever button was chosen.
    private static func requestPermissions() {
        DispatchQueue.main.async {
            // A picker that opened before the refusal would stay empty
            for w in NSApp.windows where ["Screen Selector", "Window Selector", "App Selector"].map(\.local).contains(w.title) { w.close() }
            switch ScreenAccess.refused(userAsked: true, allowedInSettings: CGPreflightScreenCaptureAccess()) {
            case .none:
                break
            case .explain:
                let alert = createAlert(title: "Permission Required",
                                        message: "QuickRecorder needs screen recording permissions, even if you only intend on recording audio.",
                                        button1: "Open Settings",
                                        button2: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
            case .reopen:
                let alert = createAlert(title: "Reopen QuickRecorder",
                                        message: "Screen recording is allowed in System Settings, and takes effect once QuickRecorder is reopened.",
                                        button1: "Reopen",
                                        button2: "Later")
                if alert.runModal() == .alertFirstButtonReturn { reopen() }
            }
        }
    }

    /// Quits, then opens again from a shell once this instance is gone: a second instance would be told to quit
    private static func reopen() {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? shell.run()
        NSApp.terminate(nil)
    }
    
    static func requestCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized, .restricted, .notDetermined:
            break
        case .denied:
            DispatchQueue.main.async {
                let alert = createAlert(title: "Permission Required",
                                                           message: "QuickRecorder needs this permission to record your camera or mobile device.",
                                                           button1: "Open Settings",
                                                           button2: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                }
            }
        @unknown default:
            break
        }
    }
    
    static func getWallpaper(_ display: SCDisplay) -> NSImage? {
        guard let screen = display.nsScreen else { return nil }
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        do {
            var wallpaper: NSImage?
            try wallpaper = NSImage(data: Data(contentsOf: url))
            if let w = wallpaper { return w }
        } catch {
            print("load wallpaper error: \(error)")
        }
        return nil
    }
    
    static func getRecordingSize() -> String {
        do {
            let fileAttr = try fd.attributesOfItem(atPath: filePath)
            let byteFormat = ByteCountFormatter()
            byteFormat.allowedUnits = [.useMB]
            byteFormat.countStyle = .file
            return byteFormat.string(fromByteCount: fileAttr[FileAttributeKey.size] as! Int64)
        } catch {
            print(String(format: "failed to fetch file for size indicator: %@".local, error.localizedDescription))
        }
        return "Unknown".local
    }
    
    /// Starts the clock at the first frame (or audio sample) written. Called from the capture queues.
    static func startClock() {
        let now = ProcessInfo.processInfo.systemUptime
        DispatchQueue.main.async {
            clock = RecordingClock()
            clock.start(at: now)
        }
    }

    static func recordingElapsed() -> TimeInterval {
        clock.elapsed(at: ProcessInfo.processInfo.systemUptime)
    }

    static func getRecordingLength() -> String {
        ElapsedTime.text(recordingElapsed()) ?? "Unknown".local
    }
    
    static func isCameraRunning() -> Bool {
        var preview = false
        var capture = false
        if let session = previewSession { preview = session.isRunning }
        if let session = captureSession { capture = session.isRunning }
        return (preview || capture)
    }
    
    static func pauseRecording() {
        isPaused.toggle()
        let now = ProcessInfo.processInfo.systemUptime
        if isPaused {
            clock.pause(at: now)
        } else {
            isResume = true
            clock.resume(at: now)
        }
        DispatchQueue.main.async { RecordingControls.shared.pauseChanged() }
    }
    
    static func stopRecording() {
        if ud.bool(forKey: "preventSleep") { SleepPreventer.shared.allowSleep() }
        autoStop = 0
        lastPTS = nil
        recordCam = ""
        recordDevice = ""
        mousePointer.orderOut(nil)
        AppDelegate.shared.stopGlobalMouseMonitor()

        if let w = NSApp.windows.first(where:  { $0.title == "Area Overlayer".local }) { w.close() }
        if let observer = recordedAppsObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        recordedAppsObserver = nil
        
        // Every source stops, and what it has already delivered is written, before any input is finished:
        // appending to a finished input raises, which quit the app on stopping (#6)
        if stream != nil {
            let stopped = DispatchSemaphore(value: 0)
            let asked = Date()
            stream.stopCapture { _ in stopped.signal() }
            let waited = stopped.wait(timeout: .now() + 1) == .success
            log.info("Capture stopped \(waited ? "after" : "without confirmation, gave up after", privacy: .public) \(Int(Date().timeIntervalSince(asked) * 1000), privacy: .public) ms")
        }
        stream = nil
        if ud.bool(forKey: "recordMic") {
            AudioRecorder.shared.stop()
            if let observer = micConfigObserver { NotificationCenter.default.removeObserver(observer) }
            micConfigObserver = nil
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        videoQueue.sync {}
        audioQueue.sync {}
        if ud.bool(forKey: "recordMic") { micInput.markAsFinished() }
        let mixInto = mixedOutput
        mixedOutput = nil
        // Taken now: mixing the microphone into the main track finishes after firstFrame is cleared below
        let previewImage = firstFrame?.nsImage
        if streamType != .systemaudio {
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            vwInput.markAsFinished()
            awInput.markAsFinished()
            vW.finishWriting {
                if vW.status != .completed {
                    print("Video writing failed with status: \(vW.status), error: \(String(describing: vW.error))")
                    let err = vW.error?.localizedDescription ?? "Unknow Error"
                    showNotification(title: "Failed to save file".local, body: "\(err)", id: "quickrecorder.error.\(UUID().uuidString)")
                } else if let output = mixInto {
                    finishMixedRecording(unmixed: filePath.url, into: output, previewImage: previewImage)
                }
                dispatchGroup.leave()
            }
            dispatchGroup.wait()
        } else {
            if ud.bool(forKey: "recordMic") {
                let dispatchGroup = DispatchGroup()
                dispatchGroup.enter()
                vW.finishWriting {
                    if vW.status != .completed {
                        print("Mic writing failed with status: \(vW.status), error: \(String(describing: vW.error))")
                    }
                    dispatchGroup.leave()
                }
                dispatchGroup.wait()
            }
        }
        
        restoreRecordMic()

        DispatchQueue.main.async {
            if isCameraRunning() {
                if camWindow.isVisible { camWindow.close() }
                if deviceWindow.isVisible { deviceWindow.close() }
                if let preview = previewSession { preview.stopRunning() }
                if let capture = captureSession { capture.stopRunning() }
            }
        }
        
        audioFile = nil // close audio file
        if streamType == .systemaudio {
            // Recorded in two parts when the microphone was on at the start (filePath1 then differs from filePath)
            let parts = filePath1 != filePath ? (system: filePath1.url, microphone: filePath2.url) : nil
            let output = filePath.url
            finishing.enter()
            Task {
                await finishAudioRecording(output: output, parts: parts)
                finishing.leave()
            }
        }
        
        isPaused = false
        hideMousePointer = false
        window = nil
        screen = nil
        startTime = nil
        clock = RecordingClock()
        AppDelegate.shared.presenterType = "OFF"
        updateStatusBar()
        
        if mixInto == nil && streamType != .systemaudio {
            if let vW = vW {
                if vW.status != .completed {
                    streamType = nil
                    return
                }
            }
            if !ud.bool(forKey: "showPreview") {
                let title = "Recording Completed".local
                let body = String(format: "File saved to: %@".local, filePath)
                let id = "quickrecorder.completed.\(UUID().uuidString)"
                showNotification(title: title, body: body, id: id)
            } else {
                showPreview(path: filePath, image: previewImage)
            }
            trimVideo()
        }
        
        streamType = nil
        firstFrame = nil
    }
    
    /// Finishes an audio-only recording: mixes the system audio and microphone parts into `output`,
    /// then shows the preview or a notification.
    private static func finishAudioRecording(output: URL, parts: (system: URL, microphone: URL)?) async {
        do {
            if let parts {
                try AudioMix.mix(parts.system, parts.microphone, into: output, settings: updateAudioSettings())
                try? fd.removeItem(at: parts.system.deletingLastPathComponent())
            }
            if ud.bool(forKey: "showPreview") {
                showPreview(path: output.path, image: nil)
            } else {
                showNotification(title: "Recording Completed".local, body: String(format: "File saved to: %@".local, output.path), id: "quickrecorder.completed.\(UUID().uuidString)")
            }
        } catch {
            var body = error.localizedDescription
            if let parts {
                // Don't lose the recording: keep both parts next to where the mix should have gone
                let base = output.deletingPathExtension().path
                try? fd.moveItem(at: parts.system, to: URL(fileURLWithPath: base + "_SystemAudio." + output.pathExtension))
                try? fd.moveItem(at: parts.microphone, to: URL(fileURLWithPath: base + "_Microphone." + parts.microphone.pathExtension))
                body = "Mixing failed. The system audio and the microphone were saved as two separate files.".local
            }
            showNotification(title: "Failed to save file".local, body: body, id: "quickrecorder.error.\(UUID().uuidString)")
        }
    }

    /// Shows the floating preview: `image` is a video's first frame; audio (nil) shows its waveform (#55).
    static func showPreview(path: String, image: NSImage?) {
        if !ud.bool(forKey: "showPreview") { return }
        DispatchQueue.main.async { PreviewController.shared.show(url: path.url, frame: image) }
    }
    
    
    static func trimVideo() {
        if ud.bool(forKey: "trimAfterRecord") {
            let fileURL = filePath.url
            AppDelegate.shared.createNewWindow(view: VideoTrimmerView(videoURL: fileURL), title: fileURL.lastPathComponent, only: false)
        }
    }
    
    static func getCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified)
        return discoverySession.devices
    }
    
    static func getMicrophone() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified)
        return discoverySession.devices.filter({ !$0.localizedName.contains("CADefaultDeviceAggregate") })
    }
    
    static func getiDevice() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .muxed, position: .unspecified)
        return discoverySession.devices
    }
    
    static func getCurrentMic() -> AVCaptureDevice? {
        let deviceName = ud.string(forKey: "micDevice")
        return getMicrophone().first(where: { $0.localizedName == deviceName })
    }
    
    /*static func getChannelCount() -> Int? {
        if let device = getCurrentMic() {
            if let channels = device.formats.first?.formatDescription.audioChannelLayout?.numberOfChannels {
                return channels
            }
            
            let activeFormat = device.activeFormat
            let description = activeFormat.formatDescription
            if let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee {
                let channelCount = audioStreamBasicDescription.mChannelsPerFrame
                return max(2, Int(channelCount))
            }
        }
        return getDefaultChannelCount()
    }
    
    static func getDefaultChannelCount() -> Int? {
        var deviceID = AudioObjectID(0)
        var propertySize = UInt32(MemoryLayout.size(ofValue: deviceID))
        
        // 获取默认音频输入设备
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            print("Failed to get default audio input device")
            return nil
        }
        
        // 获取通道数
        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // 查询流配置信息
        var streamConfig: UnsafeMutableAudioBufferListPointer?
        propertySize = 0
        
        // 先获取属性大小
        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propertySize)
        guard sizeStatus == noErr else {
            print("Failed to get size for stream configuration")
            return nil
        }
        
        // 分配内存以存储音频流配置
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propertySize))
        defer { bufferList.deallocate() }
        
        let configStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, bufferList)
        guard configStatus == noErr else {
            print("Failed to get stream configuration")
            return nil
        }
        
        streamConfig = UnsafeMutableAudioBufferListPointer(bufferList)
        
        // 计算通道总数
        var totalChannels = 0
        for buffer in streamConfig! {
            totalChannels += Int(buffer.mNumberChannels)
        }
        return max(2, totalChannels)
    }*/
    
    static func getSampleRate() -> Int? {
        if let device = getCurrentMic() {
            let activeFormat = device.activeFormat
            let description = activeFormat.formatDescription
            
            if let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee {
                let sampleRate = audioStreamBasicDescription.mSampleRate
                return Int(sampleRate)
            }
        }
        return getDefaultSampleRate()
    }
    
    static func getDefaultSampleRate() -> Int? {
        var deviceID = AudioObjectID(0)
        var propertySize = UInt32(MemoryLayout.size(ofValue: deviceID))
        
        // 获取默认音频输入设备
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            print("Failed to get default audio input device")
            return nil
        }
        
        // 获取采样率
        var sampleRate: Double = 0
        propertySize = UInt32(MemoryLayout.size(ofValue: sampleRate))
        
        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let sampleRateStatus = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &sampleRate
        )
        
        guard sampleRateStatus == noErr else {
            print("Failed to get sample rate for the default input device")
            return nil
        }
        
        return Int(sampleRate)
    }
    
    static func adjustTime(sample: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        guard CMSampleBufferGetFormatDescription(sample) != nil else { return nil }
        
        var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: Int(CMSampleBufferGetNumSamples(sample)))
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: timingInfo.count, arrayToFill: &timingInfo, entriesNeededOut: nil)
        
        for i in 0..<timingInfo.count {
            timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, offset)
            timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, offset)
        }
        
        var outSampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample, sampleTimingEntryCount: timingInfo.count, sampleTimingArray: &timingInfo, sampleBufferOut: &outSampleBuffer)
        
        return outSampleBuffer
    }
    
    static func restoreRecordMic() {
        guard let m = recordMicAfterRecording else { return }
        ud.set(m, forKey: "recordMic")
        recordMicAfterRecording = nil
    }

    /// Ends an app recording once every recorded app has quit: the capture carries on regardless, recording nothing (#7)
    static func watchRecordedApps() {
        guard let apps = application, !apps.isEmpty else { return }
        let recorded = Set(apps.map(\.processID))
        recordedAppsObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { _ in
            guard stream != nil, !NSWorkspace.shared.runningApplications.contains(where: { recorded.contains($0.processIdentifier) }) else { return }
            log.error("Every recorded app quit")
            stopRecording()
            notifyStopped(StreamStop.appsQuit.message(recordingWindows: false))
        }
    }

    /// Says why a recording ended on its own (#7). While the display is off or the screen locked a notification never shows
    /// as a banner, so this one waits until the screen is in use again.
    static func notifyStopped(_ reason: String) {
        let id = "quickrecorder.stopped.\(UUID().uuidString)"
        // Checked from a second later: the display may still be turning off when the capture ends
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            let session = CGSessionCopyCurrentDictionary() as? [String: Any]
            guard session?["CGSSessionScreenIsLocked"] as? Bool != true, CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return }
            timer.invalidate()
            showNotification(title: "Recording stopped".local, body: reason, id: id)
        }
    }

    static func showNotification(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Notification failed to send：\(error.localizedDescription)") }
        }
    }
    
    /// Mixes the microphone into the main track, keeping the recording with its tracks apart if that fails (#6),
    /// then shows the preview or opens the trimmer.
    private static func finishMixedRecording(unmixed: URL, into output: URL, previewImage: NSImage?) {
        finishing.enter()
        Task {
            defer { finishing.leave() }
            let outcome = await MixedRecording.finish(unmixed: unmixed, into: output, retryAfter: .seconds(1)) { recording, output in
                try await mixAudioTracks(from: recording, to: output)
            }
            var saved = output
            switch outcome {
            case .mixed:
                if !ud.bool(forKey: "showPreview") {
                    showNotification(title: "Recording Completed".local, body: String(format: "File saved to: %@".local, output.path), id: "quickrecorder.completed.\(UUID().uuidString)")
                }
            case .keptUnmixed(let url, let reason):
                saved = url
                log.error("Mixing the microphone into the main track failed twice: \(reason, privacy: .public)")
                showNotification(title: "Couldn't mix the microphone into the main track".local,
                                 body: "The recording was saved with the microphone on a track of its own.".local,
                                 id: "quickrecorder.error.\(UUID().uuidString)")
            }
            DispatchQueue.main.async {
                if ud.bool(forKey: "trimAfterRecord") {
                    AppDelegate.shared.createNewWindow(view: VideoTrimmerView(videoURL: saved), title: saved.lastPathComponent, only: false)
                } else {
                    showPreview(path: saved.path, image: previewImage)
                }
            }
        }
    }

    /// Mixes all audio tracks of `recording` into one (an export to a temporary file), then puts that with the video in `output` (a passthrough export).
    static func mixAudioTracks(from recording: URL, to output: URL) async throws {
        let asset = AVURLAsset(url: recording)
        let mixedAudio = fd.temporaryDirectory.appendingPathComponent("QuickRecorder-\(UUID().uuidString)").appendingPathExtension(output.pathExtension)
        defer { try? fd.removeItem(at: mixedAudio) }
        let audioOnlyComposition = AVMutableComposition()
        let fileType = TrimExport.fileType(for: output)

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard audioTracks.count > 1 else {
            throw NSError(domain: "AudioTrackError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not enough audio tracks found."])
        }
        let duration = try await asset.load(.duration)

        for audioTrack in audioTracks {
            if let compositionAudioTrack = audioOnlyComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                do {
                    try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
                } catch {
                    throw NSError(domain: "AudioTrackInsertionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert audio track: \(error.localizedDescription)"])
                }
            }
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioTracks.map {
            let parameters = AVMutableAudioMixInputParameters(track: $0)
            parameters.trackID = $0.trackID
            return parameters
        }

        guard let audioExportSession = AVAssetExportSession(asset: audioOnlyComposition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "AudioExportSessionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio export session."])
        }
        audioExportSession.audioMix = audioMix
        try await audioExportSession.export(to: mixedAudio, as: fileType ?? .mp4)

        let audioAsset = AVURLAsset(url: mixedAudio)
        let composition = AVMutableComposition()

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "VideoTrackError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get video track."])
        }

        do {
            try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
        } catch {
            throw NSError(domain: "VideoTrackInsertionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert video track: \(error.localizedDescription)"])
        }

        let mixedAudioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        guard mixedAudioTracks.count >= 1 else {
            throw NSError(domain: "AudioTrackError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not enough audio tracks found."])
        }

        for audioTrack in mixedAudioTracks {
            if let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                do {
                    try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
                } catch {
                    throw NSError(domain: "AudioTrackInsertionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert audio track: \(error.localizedDescription)"])
                }
            }
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw NSError(domain: "ExportSessionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."])
        }
        exportSession.audioMix = audioMix
        try await exportSession.export(to: output, as: fileType ?? .mp4)
    }
}

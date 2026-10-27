//
//  SettingValues.swift
//  QuickRecorder
//
//  Raw values stored in UserDefaults for the recording settings.
//

enum AudioQuality: Int { case normal = 128, good = 192, high = 256, extreme = 320 }

enum AudioFormat: String {
    case aac, alac

    /// The stored "audioFormat" setting; formats that are no longer offered (mp3, opus, flac) read as AAC.
    init(stored: String?) { self = AudioFormat(rawValue: stored ?? "") ?? .aac }
}

enum VideoFormat: String { case mov, mp4 }

enum Encoder: String { case h264, h265 }

enum StreamType: Int { case screen, window, windows, application, screenarea, systemaudio, idevice, camera }

enum BackgroundType: String { case wallpaper, clear, black, white, red, green, yellow, orange, gray, blue, custom }

/// The material of the main panel and the floating capsule, stored as "capsuleMaterial" from when only the capsule had one
enum PanelMaterial: String { case glass, blur, black }

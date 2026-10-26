//
//  SettingValues.swift
//  QuickRecorder
//
//  Raw values stored in UserDefaults for the recording settings.
//

enum AudioQuality: Int { case normal = 128, good = 192, high = 256, extreme = 320 }

enum AudioFormat: String { case aac, alac, flac, opus, mp3 }

enum VideoFormat: String { case mov, mp4 }

enum Encoder: String { case h264, h265 }

enum StreamType: Int { case screen, window, windows, application, screenarea, systemaudio, idevice, camera }

enum BackgroundType: String { case wallpaper, clear, black, white, red, green, yellow, orange, gray, blue, custom }

enum CapsuleMaterial: String { case glass, blur, black }

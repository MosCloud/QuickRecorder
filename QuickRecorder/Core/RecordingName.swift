//
//  RecordingName.swift
//  QuickRecorder
//

import Foundation

/// File names in the system's words, in English and without spaces whatever the system language (#61):
/// "ScreenRecording_2026-10-26_15.04.05.mp4", "AudioRecording_…", "Screenshot_…".
enum RecordingName {
    enum Kind: String {
        case screenRecording = "ScreenRecording"
        case audioRecording = "AudioRecording"
        case screenshot = "Screenshot"
    }

    /// Path of a new recording or captured frame without its extension.
    static func path(directory: String, kind: Kind, date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        // Fixed digits and calendar: the system's locale could bring other numerals or a Buddhist year
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        formatter.timeZone = timeZone
        return directory + "/" + kind.rawValue + "_" + formatter.string(from: date)
    }

    /// "<recording>_Trimmed.<ext>" next to the recording, then "_Trimmed-2", "_Trimmed-3"… while the name is taken.
    static func trimmed(_ source: URL, exists: (URL) -> Bool) -> URL {
        let base = source.deletingPathExtension().lastPathComponent + "_Trimmed"
        let folder = source.deletingLastPathComponent()
        var number = 1
        while true {
            let url = folder.appendingPathComponent(number == 1 ? base : "\(base)-\(number)").appendingPathExtension(source.pathExtension)
            if !exists(url) { return url }
            number += 1
        }
    }
}

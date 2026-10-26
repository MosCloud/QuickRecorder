//
//  RecordingName.swift
//  QuickRecorder
//

import Foundation

enum RecordingName {
    /// Path of a new recording or captured frame without its extension, e.g. "/Users/me/Desktop/Recording at 2026-10-26 15.04.05".
    /// `prefix` is the localized "/Recording at " or "/Capturing at ", leading slash included.
    static func path(directory: String, prefix: String, date: Date, timeZone: TimeZone = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
        dateFormatter.timeZone = timeZone
        return directory + prefix + dateFormatter.string(from: date)
    }
}

//
//  DisplayPick.swift
//  QuickRecorder
//

import Foundation

/// Which display a scripted recording uses (#72). Generic over the display type, ScreenCaptureKit's in the app.
enum DisplayPick {
    /// The pointer's display if it's one of `candidates` (the displays a window is on), else the first candidate;
    /// without candidates, the pointer's display, else any. The pointer's can be missing, with the screen locked or asleep.
    static func pick<Display: Equatable>(pointer: Display?, candidates: [Display], all: [Display]) -> Display? {
        if candidates.isEmpty { return pointer ?? all.first }
        if let pointer, candidates.contains(pointer) { return pointer }
        return candidates.first
    }
}

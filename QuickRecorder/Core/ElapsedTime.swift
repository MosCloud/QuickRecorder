//
//  ElapsedTime.swift
//  QuickRecorder
//

import Foundation

enum ElapsedTime {
    /// Recording length as shown in the menu bar: minutes and seconds, minutes keep counting past an hour ("61:01").
    static func text(_ seconds: TimeInterval) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: seconds)
    }
}

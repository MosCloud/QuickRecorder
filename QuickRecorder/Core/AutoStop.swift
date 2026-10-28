//
//  AutoStop.swift
//  QuickRecorder
//

import Foundation

/// The timer on the selectors' bars that stops a recording after a set time (#86)
struct AutoStop: Equatable {
    static let hourRange = 0...23
    static let minuteRange = 0...59
    static let secondRange = 0...59

    var hours = 0
    var minutes = 0
    var seconds = 0

    /// In seconds, 0 for never
    var limit: TimeInterval { TimeInterval(hours * 3600 + minutes * 60 + seconds) }

    /// A limit of 0 or less never stops a recording: the minutes stepper went down to -1, which stopped one at once
    static func isDue(limit: TimeInterval, elapsed: TimeInterval) -> Bool {
        limit > 0 && elapsed >= limit
    }
}

extension ClosedRange where Bound == Int {
    /// The nearest value in the range
    func clamp(_ value: Int) -> Int { Swift.min(Swift.max(value, lowerBound), upperBound) }
}

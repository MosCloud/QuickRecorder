//
//  AutoStop.swift
//  QuickRecorder
//

import Foundation

/// The timer on the selectors' bars that stops a recording after a set time (#86)
struct AutoStop: Equatable {
    static let hourRange = 0...99
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

/// The timer as a toggle beside the microphone (#79): a click switches it, keeping its duration while off
extension AutoStop {
    /// What switching on without a duration takes, as the microphone takes the system's default device
    static let defaultDuration = AutoStop(minutes: 10)

    init(totalSeconds: Int) {
        self.init(hours: totalSeconds / 3600, minutes: totalSeconds % 3600 / 60, seconds: totalSeconds % 60)
    }

    var totalSeconds: Int { hours * 3600 + minutes * 60 + seconds }

    /// A click on the timer
    static func toggled(on: Bool, duration: AutoStop) -> (on: Bool, duration: AutoStop) {
        if on { return (false, duration) }
        return (true, duration.limit > 0 ? duration : defaultDuration)
    }

    /// Whether the timer stays on once its duration is edited: editing doesn't switch it, but a timer of nothing can't run
    static func staysOn(_ on: Bool, after duration: AutoStop) -> Bool { on && duration.limit > 0 }
}

extension ClosedRange where Bound == Int {
    /// The value if it's in the range, else 0: what a timer field does with a number typed past its ends
    func orZero(_ value: Int) -> Int { contains(value) ? value : 0 }
}

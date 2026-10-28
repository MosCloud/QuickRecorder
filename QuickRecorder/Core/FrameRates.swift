//
//  FrameRates.swift
//  QuickRecorder
//

import Foundation

/// The frame rates a recording can use on a display (#79)
enum FrameRates {
    static let usual = [10, 15, 24, 30, 60, 90, 120, 144, 240]

    /// The usual rates up to the display's top refresh rate, and that rate itself
    static func available(maxFPS: Int) -> [Int] {
        let top = topRate(maxFPS)
        return usual.filter { $0 < top } + [top]
    }

    /// What a recording on the display gets: the setting, or the display's top rate below it. The setting itself is
    /// kept, for the next recording on a faster display.
    static func effective(_ setting: Int, maxFPS: Int) -> Int { min(setting, topRate(maxFPS)) }

    /// A display that doesn't say (0) counts as 60 Hz
    private static func topRate(_ maxFPS: Int) -> Int { maxFPS > 0 ? maxFPS : 60 }
}

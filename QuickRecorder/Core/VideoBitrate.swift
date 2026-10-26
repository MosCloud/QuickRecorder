//
//  VideoBitrate.swift
//  QuickRecorder
//

import Foundation

enum VideoBitrate {
    /// Average bitrate (bits per second) requested from the video encoder.
    /// `quality` is the "videoQuality" setting: 1.0 high, 0.7 medium, 0.3 low.
    static func target(width: Int, height: Int, frameRate: Int, isHEVC: Bool, quality: Double, isHDR: Bool) -> Int {
        let fpsMultiplier: Double = Double(frameRate)/8
        let encoderMultiplier: Double = isHEVC ? 0.5 : 0.9
        let resolution = Double(max(600, width)) * Double(max(600, height))
        var qualityMultiplier = 1 - (log10(sqrt(resolution) * fpsMultiplier) / 5)
        switch quality {
            case 0.3: qualityMultiplier = max(0.1, qualityMultiplier)
            case 0.7: qualityMultiplier = max(0.4, min(0.6, qualityMultiplier * 3))
            default: qualityMultiplier = 1.0
        }
        let targetBitrate = resolution * fpsMultiplier * encoderMultiplier * qualityMultiplier * (isHDR ? 2 : 1)
        return max(200000, Int(targetBitrate))
    }
}

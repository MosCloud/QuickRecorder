//
//  RecordingPreview.swift
//  QuickRecorder
//

import AVFoundation

/// What the floating preview shows about a recording (#55).
enum RecordingPreview {
    /// "0:21", "1:05", "1:02:03"
    static func duration(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let (hours, minutes, rest) = (total / 3600, total % 3600 / 60, total % 60)
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }

    /// The loudest moment of each of `bars` equal stretches of an audio recording, from 0 (−50 dB or quieter) to 1 (full scale).
    static func waveform(of url: URL, bars: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let perBar = AVAudioFrameCount(max(1, file.length / AVAudioFramePosition(bars)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: perBar) else { return [] }
        return try (0..<bars).map { _ in
            try file.read(into: buffer, frameCount: perBar)
            var peak: Float = 0
            for channel in 0..<Int(format.channelCount) {
                let samples = buffer.floatChannelData![channel]
                for frame in 0..<Int(buffer.frameLength) { peak = max(peak, abs(samples[frame])) }
            }
            return peak > 0 ? min(1, max(0, (20 * log10(peak) + 50) / 50)) : 0
        }
    }
}

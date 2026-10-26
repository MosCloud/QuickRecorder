//
//  AudioSettings.swift
//  QuickRecorder
//

import AVFoundation

enum AudioSettings {
    /// AVFoundation output settings for an audio track.
    /// - Parameters:
    ///   - format: an `AudioFormat` raw value; anything but ALAC records as AAC.
    ///   - qualityKbps: the "audioQuality" setting (an `AudioQuality` raw value).
    static func make(format: String, sampleRate: Int, qualityKbps: Int) -> [String : Any] {
        var audioSettings: [String : Any] = [AVSampleRateKey : sampleRate, AVNumberOfChannelsKey : 2]
        var bitRate = qualityKbps * 1000
        if sampleRate < 44100 { bitRate = min(64000, bitRate / 2) }
        if format == AudioFormat.alac.rawValue {
            audioSettings[AVFormatIDKey] = kAudioFormatAppleLossless
            audioSettings[AVEncoderBitDepthHintKey] = 16
        } else {
            // AAC, and anything else: formats no longer offered still record
            audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            audioSettings[AVEncoderBitRateKey] = bitRate
        }
        return audioSettings
    }
}

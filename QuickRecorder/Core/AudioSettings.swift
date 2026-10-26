//
//  AudioSettings.swift
//  QuickRecorder
//

import AVFoundation

enum AudioSettings {
    /// AVFoundation output settings for an audio track.
    /// - Parameters:
    ///   - format: an `AudioFormat` raw value; unknown values get no `AVFormatIDKey`.
    ///   - qualityKbps: the "audioQuality" setting (an `AudioQuality` raw value).
    ///   - videoFormat: the "videoFormat" setting; Opus can only go into a .mov container, so .mp4 falls back to AAC.
    static func make(format: String, sampleRate: Int, qualityKbps: Int, videoFormat: String?) -> [String : Any] {
        var audioSettings: [String : Any] = [AVSampleRateKey : sampleRate, AVNumberOfChannelsKey : 2]
        var bitRate = qualityKbps * 1000
        if sampleRate < 44100 { bitRate = min(64000, bitRate / 2) }
        switch format {
        case AudioFormat.mp3.rawValue: fallthrough
        case AudioFormat.aac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            audioSettings[AVEncoderBitRateKey] = bitRate
        case AudioFormat.alac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatAppleLossless
            audioSettings[AVEncoderBitDepthHintKey] = 16
        case AudioFormat.flac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatFLAC
        case AudioFormat.opus.rawValue:
            audioSettings[AVFormatIDKey] = videoFormat != VideoFormat.mp4.rawValue ? kAudioFormatOpus : kAudioFormatMPEG4AAC
            audioSettings[AVEncoderBitRateKey] =  bitRate
        default:
            break
        }
        return audioSettings
    }
}

//
//  MicConverter.swift
//  QuickRecorder
//

import AVFoundation

/// Keeps the microphone track in the format it started in. A device that changes mid-recording, such as a headset
/// connecting or switching to its call mode, can bring another sample rate or channel count, which the track can't take.
final class MicConverter {
    let target: AVAudioFormat
    /// Kept across buffers so the resampler runs on without gaps
    private var converter: AVAudioConverter?

    init(target: AVAudioFormat) {
        self.target = target
    }

    /// `buffer` in the target format: the buffer itself when it already is.
    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == target { return buffer }
        if converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
            // A mono microphone goes to every channel, not only the first
            if buffer.format.channelCount == 1 { converter?.channelMap = Array(repeating: 0, count: Int(target.channelCount)) }
        }
        guard let converter else { return nil }
        let frames = (Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate).rounded(.up)
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(frames) + 32) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            // One buffer per call; "no data now" rather than "end of stream" keeps the resampler going for the next
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return status == .error ? nil : output
    }
}

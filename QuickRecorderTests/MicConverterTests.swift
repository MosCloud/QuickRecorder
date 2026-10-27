//
//  MicConverterTests.swift
//  QuickRecorderTests
//
//  Keeping the microphone track in one format when the input device changes mid-recording (issue #50).
//

import AVFoundation
import Foundation
import Testing

@Suite("Microphone format")
struct MicConverterTests {
    /// `seconds` of input in 100 ms buffers, every sample `level`
    func buffers(_ format: AVAudioFormat, seconds: Double, level: Float = 0.5) throws -> [AVAudioPCMBuffer] {
        let frames = AVAudioFrameCount(format.sampleRate / 10)
        return try (0..<Int(seconds * 10)).map { _ in
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
            buffer.frameLength = frames
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frames) { buffer.floatChannelData![channel][frame] = level }
            }
            return buffer
        }
    }

    func format(_ sampleRate: Double, _ channels: AVAudioChannelCount) throws -> AVAudioFormat {
        try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
    }

    @Test("Buffers already in the track's format pass through untouched")
    func sameFormat() throws {
        let converter = MicConverter(target: try format(16000, 1))
        let buffer = try buffers(try format(16000, 1), seconds: 0.1)[0]
        #expect(converter.convert(buffer) === buffer)
    }

    @Test("After a switch to another sample rate, the buffers are resampled to the track's and keep their duration")
    func otherSampleRate() throws {
        // A Bluetooth headset at 16 kHz, then the built-in microphone at 48 kHz
        let converter = MicConverter(target: try format(16000, 1))
        let output = try buffers(try format(48000, 1), seconds: 1).compactMap { converter.convert($0) }
        #expect(output.allSatisfy { $0.format == converter.target })
        let frames = output.reduce(0) { $0 + Int($1.frameLength) }
        #expect(abs(frames - 16000) < 320, "1 s at 16 kHz, give or take the resampler's latency: \(frames)")
        #expect(abs(output[5].floatChannelData![0][800] - 0.5) < 0.05)
    }

    @Test("A mono microphone fills both channels of a stereo track")
    func monoToStereo() throws {
        let converter = MicConverter(target: try format(48000, 2))
        let output = try buffers(try format(48000, 1), seconds: 0.5).compactMap { converter.convert($0) }
        let last = try #require(output.last)
        #expect(last.format.channelCount == 2)
        for channel in 0..<2 {
            #expect(abs(last.floatChannelData![channel][1000] - 0.5) < 0.05, "channel \(channel)")
        }
    }
}

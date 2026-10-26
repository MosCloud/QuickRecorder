//
//  AudioMixTests.swift
//  QuickRecorderTests
//
//  Mixing the system audio and the microphone of an audio-only recording (issue #20).
//

import AVFoundation
import Foundation
import Testing

@Suite("Audio mix")
struct AudioMixTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// A stereo file in which every sample is `level`.
    func constant(_ level: Float, seconds: Double, sampleRate: Double, name: String) throws -> URL {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2))
        let url = directory.appendingPathComponent(name)
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0..<2 {
            for frame in 0..<Int(frames) { buffer.floatChannelData![channel][frame] = level }
        }
        try file.write(from: buffer)
        return url
    }

    @Test("Both recordings play at once, for as long as the longer one, even at different sample rates")
    func mixesBoth() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let system = try constant(0.25, seconds: 1, sampleRate: 48000, name: "system.caf")
        let microphone = try constant(0.5, seconds: 0.5, sampleRate: 44100, name: "mic.caf")
        let output = directory.appendingPathComponent("mixed.caf")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))

        try AudioMix.mix(system, microphone, into: output, settings: format.settings)

        let mixed = try AVAudioFile(forReading: output)
        #expect(mixed.length == 48000)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: mixed.processingFormat, frameCapacity: 48000))
        try mixed.read(into: buffer)
        for channel in 0..<2 {
            let samples = buffer.floatChannelData![channel]
            #expect(abs(samples[12000] - 0.75) < 0.01, "0.25 s in: system + microphone")
            #expect(abs(samples[36000] - 0.25) < 0.01, "0.75 s in: the microphone has ended")
        }
    }
}

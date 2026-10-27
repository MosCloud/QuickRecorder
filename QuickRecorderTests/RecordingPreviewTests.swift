//
//  RecordingPreviewTests.swift
//  QuickRecorderTests
//
//  What the floating preview shows about a recording: its length and an audio recording's waveform (issue #55).
//

import AVFoundation
import Foundation
import Testing

@Suite("Recording preview")
struct RecordingPreviewTests {
    @Test("Lengths read like a player's", arguments: [
        (0.4, "0:00"), (21.6, "0:21"), (65, "1:05"), (3723, "1:02:03"),
    ])
    func duration(seconds: Double, text: String) {
        #expect(RecordingPreview.duration(seconds) == text)
    }

    @Test("The waveform is quiet where the recording is and loud where it is, one level per bar")
    func waveform() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // One second of silence, then one second of a tone at half scale
        let url = directory.appendingPathComponent("recording.m4a")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        do {
            let file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88200))
            buffer.frameLength = 88200
            for i in 0..<88200 { buffer.floatChannelData![0][i] = i < 44100 ? 0 : Float(sin(Double(i) * 0.1) * 0.5) }
            try file.write(from: buffer)
        }

        let levels = try RecordingPreview.waveform(of: url, bars: 20)

        try #require(levels.count == 20)
        #expect(levels[2...7].allSatisfy { $0 < 0.1 }, "silence: \(levels)")
        #expect(levels[12...17].allSatisfy { $0 > 0.8 }, "the tone: \(levels)")
    }
}

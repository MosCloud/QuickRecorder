//
//  TrimExportTests.swift
//  QuickRecorderTests
//
//  Saving a trimmed copy of a recording, audio included (issue #56).
//

import AVFoundation
import Foundation
import Testing

@Suite("Trim export")
struct TrimExportTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test("A trimmed copy keeps the recording's own file type, audio included", arguments: [
        ("录制于 2026-10-27 10.21.58.mp4", AVFileType.mp4),
        ("Recording.MOV", .mov),
        ("录制于 2026-10-27 10.23.40.m4a", .m4a),
    ])
    func fileType(name: String, type: AVFileType) {
        #expect(TrimExport.fileType(for: URL(fileURLWithPath: name)) == type)
    }

    @Test("Formats a recording is never saved in have no type, so the trimmer can say so")
    func unknown() {
        #expect(TrimExport.fileType(for: URL(fileURLWithPath: "notes.txt")) == nil)
    }

    @Test("One second out of a three-second audio recording")
    func audio() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("recording.m4a")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        do {
            let file = try AVAudioFile(forWriting: source, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 3))
            buffer.frameLength = 44100 * 3
            for i in 0..<Int(buffer.frameLength) { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 0.05) * 0.3) }
            try file.write(from: buffer)
        }
        let output = directory.appendingPathComponent("trimmed.m4a")

        try await TrimExport.export(source, range: CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 600),
                                                               end: CMTime(seconds: 2, preferredTimescale: 600)), to: output)

        let duration = try await AVURLAsset(url: output).load(.duration).seconds
        #expect(abs(duration - 1) < 0.1, "\(duration) s")
    }
}

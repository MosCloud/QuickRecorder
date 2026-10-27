//
//  CoreTests.swift
//  QuickRecorderTests
//
//  Characterization tests: they pin down what the app does today, so later
//  fixes change behaviour on purpose rather than by accident.
//

import AVFoundation
import Foundation
import Testing

@Suite("Video bitrate")
struct VideoBitrateTests {
    @Test("High quality: pixels × fps/8 × codec factor", arguments: [
        (isHEVC: true, isHDR: false, expected: 7_776_000),
        (isHEVC: false, isHDR: false, expected: 13_996_800),
        (isHEVC: true, isHDR: true, expected: 15_552_000),
    ])
    func highQuality(isHEVC: Bool, isHDR: Bool, expected: Int) {
        #expect(VideoBitrate.target(width: 1920, height: 1080, frameRate: 60, isHEVC: isHEVC, quality: 1.0, isHDR: isHDR) == expected)
    }

    @Test("Medium and low quality scale down by resolution and frame rate")
    func lowerQualities() {
        #expect(VideoBitrate.target(width: 1920, height: 1080, frameRate: 60, isHEVC: true, quality: 0.7, isHDR: false) == 4_509_658)
        #expect(VideoBitrate.target(width: 1920, height: 1080, frameRate: 60, isHEVC: true, quality: 0.3, isHDR: false) == 1_503_219)
    }

    @Test("Medium quality factor is clamped to 0.4…0.6, low quality to at least 0.1")
    func qualityClamps() {
        #expect(VideoBitrate.target(width: 1280, height: 720, frameRate: 30, isHEVC: true, quality: 0.7, isHDR: false) == 1_036_800)
        #expect(VideoBitrate.target(width: 3840, height: 2160, frameRate: 60, isHEVC: true, quality: 0.7, isHDR: false) == 12_441_600)
        #expect(VideoBitrate.target(width: 3840, height: 2160, frameRate: 120, isHEVC: true, quality: 0.3, isHDR: false) == 6_220_800)
    }

    @Test("Sides shorter than 600 count as 600; never below 200 kbit/s")
    func floors() {
        #expect(VideoBitrate.target(width: 100, height: 100, frameRate: 30, isHEVC: false, quality: 1.0, isHDR: false) == 1_215_000)
        #expect(VideoBitrate.target(width: 600, height: 600, frameRate: 1, isHEVC: true, quality: 0.3, isHDR: false) == 200_000)
    }
}

@Suite("Audio settings")
struct AudioSettingsTests {
    @Test("AAC records at the chosen bitrate")
    func aac() {
        let settings = AudioSettings.make(format: "aac", sampleRate: 48000, qualityKbps: 256)
        #expect(settings[AVFormatIDKey] as? AudioFormatID == kAudioFormatMPEG4AAC)
        #expect(settings[AVEncoderBitRateKey] as? Int == 256_000)
        #expect(settings[AVSampleRateKey] as? Int == 48000)
        #expect(settings[AVNumberOfChannelsKey] as? Int == 2)
    }

    @Test("Formats no longer offered, and unknown ones, record as AAC", arguments: ["mp3", "opus", "flac", "wav"])
    func fallsBackToAAC(format: String) {
        let settings = AudioSettings.make(format: format, sampleRate: 48000, qualityKbps: 256)
        #expect(settings[AVFormatIDKey] as? AudioFormatID == kAudioFormatMPEG4AAC)
        #expect(settings[AVEncoderBitRateKey] as? Int == 256_000)
    }

    @Test("Below 44.1 kHz the bitrate is halved and capped at 64 kbit/s")
    func lowSampleRate() {
        #expect(AudioSettings.make(format: "aac", sampleRate: 22050, qualityKbps: 256)[AVEncoderBitRateKey] as? Int == 64_000)
        #expect(AudioSettings.make(format: "aac", sampleRate: 22050, qualityKbps: 96)[AVEncoderBitRateKey] as? Int == 48_000)
    }

    @Test("ALAC is lossless and carries no bitrate")
    func lossless() {
        let alac = AudioSettings.make(format: "alac", sampleRate: 48000, qualityKbps: 256)
        #expect(alac[AVFormatIDKey] as? AudioFormatID == kAudioFormatAppleLossless)
        #expect(alac[AVEncoderBitDepthHintKey] as? Int == 16)
        #expect(alac[AVEncoderBitRateKey] == nil)
    }
}

@Suite("Audio format setting")
struct AudioFormatSettingTests {
    @Test("A stored format that is no longer offered reads as AAC", arguments: [
        (stored: "aac", format: AudioFormat.aac),
        (stored: "alac", format: AudioFormat.alac),
        (stored: "mp3", format: AudioFormat.aac),
        (stored: "opus", format: AudioFormat.aac),
        (stored: "flac", format: AudioFormat.aac),
        (stored: nil, format: AudioFormat.aac),
    ] as [(stored: String?, format: AudioFormat)])
    func stored(stored: String?, format: AudioFormat) {
        #expect(AudioFormat(stored: stored) == format)
    }
}

@Suite("Recording names")
struct RecordingNameTests {
    let date = Date(timeIntervalSince1970: 1_793_027_045) // 2026-10-26 15:04:05 UTC

    @Test("The system's names in English, with no spaces, whatever the system language (#61)", arguments: [
        (RecordingName.Kind.screenRecording, "/Users/me/Desktop/ScreenRecording_2026-10-26_15.04.05"),
        (.audioRecording, "/Users/me/Desktop/AudioRecording_2026-10-26_15.04.05"),
        (.screenshot, "/Users/me/Desktop/Screenshot_2026-10-26_15.04.05"),
    ])
    func path(kind: RecordingName.Kind, expected: String) throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(RecordingName.path(directory: "/Users/me/Desktop", kind: kind, date: date, timeZone: utc) == expected)
    }

    @Test("A trimmed copy is named after its recording, numbered while the name is taken")
    func trimmed() {
        let source = URL(fileURLWithPath: "/Users/me/Desktop/ScreenRecording_2026-10-26_15.04.05.mp4")
        var taken = Set<String>()
        func next() -> String { RecordingName.trimmed(source, exists: { taken.contains($0.lastPathComponent) }).lastPathComponent }

        #expect(next() == "ScreenRecording_2026-10-26_15.04.05_Trimmed.mp4")
        taken.insert(next())
        #expect(next() == "ScreenRecording_2026-10-26_15.04.05_Trimmed-2.mp4")
        taken.insert(next())
        #expect(next() == "ScreenRecording_2026-10-26_15.04.05_Trimmed-3.mp4")
    }
}

@Suite("Elapsed time")
struct ElapsedTimeTests {
    @Test("Minutes and seconds, minutes keep counting past an hour", arguments: [
        (seconds: 0.0, text: "00:00"),
        (seconds: 65.0, text: "01:05"),
        (seconds: 3661.0, text: "61:01"),
    ])
    func text(seconds: Double, text: String) {
        #expect(ElapsedTime.text(seconds) == text)
    }
}

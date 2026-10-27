//
//  MixedRecordingTests.swift
//  QuickRecorderTests
//
//  Finishing a recording whose microphone is mixed into the main track (issue #6).
//

import Foundation
import Testing

@Suite("Mixed recording")
struct MixedRecordingTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var output: URL { directory.appendingPathComponent("ScreenRecording_2026-10-27_10.21.58.mp4") }
    var unmixed: URL { MixedRecording.unmixedURL(for: output) }

    struct MixFailed: Error, CustomStringConvertible { var description: String { "export interrupted" } }

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func recordUnmixed() throws {
        try Data("separate tracks".utf8).write(to: unmixed)
    }

    func contents(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    @Test("Recorded next to the final file under a name that says it isn't mixed yet")
    func unmixedName() {
        #expect(unmixed.lastPathComponent == "ScreenRecording_2026-10-27_10.21.58_Unmixed.mp4")
        #expect(unmixed.deletingLastPathComponent().path == directory.path)
    }

    @Test("Mixed at the first try: the final file is the mix, and the unmixed one goes")
    func mixed() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try recordUnmixed()
        var tries = 0
        let outcome = await MixedRecording.finish(unmixed: unmixed, into: output, retryAfter: .zero) { _, output in
            tries += 1
            try Data("mixed".utf8).write(to: output)
        }
        #expect(outcome == .mixed)
        #expect(tries == 1)
        #expect(contents(output) == "mixed")
        #expect(!FileManager.default.fileExists(atPath: unmixed.path))
    }

    @Test("A failed first try is tried once more, over whatever it left behind")
    func retried() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try recordUnmixed()
        var tries = 0
        let outcome = await MixedRecording.finish(unmixed: unmixed, into: output, retryAfter: .zero) { _, output in
            tries += 1
            if tries == 1 {
                try Data("half".utf8).write(to: output)
                throw MixFailed()
            }
            try Data("mixed".utf8).write(to: output)
        }
        #expect(outcome == .mixed)
        #expect(tries == 2)
        #expect(contents(output) == "mixed")
    }

    @Test("When both tries fail, the unmixed recording takes the final name: nothing is lost or left as an odd file")
    func keptUnmixed() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try recordUnmixed()
        let outcome = await MixedRecording.finish(unmixed: unmixed, into: output, retryAfter: .zero) { _, output in
            try Data("half".utf8).write(to: output)
            throw MixFailed()
        }
        #expect(outcome == .keptUnmixed(at: output, reason: "export interrupted"))
        #expect(contents(output) == "separate tracks")
        #expect(!FileManager.default.fileExists(atPath: unmixed.path))
    }
}

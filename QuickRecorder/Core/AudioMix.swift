//
//  AudioMix.swift
//  QuickRecorder
//

import AVFoundation

enum AudioMix {
    struct RenderError: Error {}

    /// Mixes two recordings into one file, as if they played together: as long as the longer one,
    /// at the sample rate in `settings`. The sources may differ in sample rate.
    static func mix(_ first: URL, _ second: URL, into output: URL, settings: [String: Any]) throws {
        let sources = try [AVAudioFile(forReading: first), AVAudioFile(forReading: second)]
        let sampleRate = (settings[AVSampleRateKey] as? NSNumber)?.doubleValue ?? 48000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { throw RenderError() }

        let engine = AVAudioEngine()
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        var players = [AVAudioPlayerNode]()
        var length = AVAudioFramePosition(0)
        for source in sources {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            // The mixer converts each source to the output's sample rate
            engine.connect(player, to: engine.mainMixerNode, format: source.processingFormat)
            player.scheduleFile(source, at: nil)
            players.append(player)
            let seconds = Double(source.length) / source.processingFormat.sampleRate
            length = max(length, AVAudioFramePosition((seconds * sampleRate).rounded()))
        }
        try engine.start()
        players.forEach { $0.play() }
        defer { engine.stop() }

        let file = try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw RenderError()
        }
        while engine.manualRenderingSampleTime < length {
            let frames = min(buffer.frameCapacity, AVAudioFrameCount(length - engine.manualRenderingSampleTime))
            guard try engine.renderOffline(frames, to: buffer) == .success else { throw RenderError() }
            try file.write(from: buffer)
        }
        file.close()
    }
}

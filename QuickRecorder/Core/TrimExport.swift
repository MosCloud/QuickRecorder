//
//  TrimExport.swift
//  QuickRecorder
//

import AVFoundation

/// Saves a trimmed copy of a recording (#56).
enum TrimExport {
    struct UnknownFormat: Error {}

    /// The type a trimmed copy keeps: the recording's own. Audio-only recordings are .m4a.
    static func fileType(for url: URL) -> AVFileType? {
        switch url.pathExtension.lowercased() {
        case "mov": .mov
        case "mp4": .mp4
        case "m4a": .m4a
        default: nil
        }
    }

    /// Copies `range` of `source` to `output` as it is, without encoding again.
    static func export(_ source: URL, range: CMTimeRange, to output: URL) async throws {
        guard let type = fileType(for: source),
              let session = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetPassthrough)
        else { throw UnknownFormat() }
        session.timeRange = range
        try await session.export(to: output, as: type)
    }
}

//
//  MixedRecording.swift
//  QuickRecorder
//

import Foundation

/// A recording whose microphone is mixed into the main track once writing ends (#6).
enum MixedRecording {
    enum Outcome: Equatable {
        case mixed
        /// Mixing failed: the recording, its microphone on a track of its own, is at `at`
        case keptUnmixed(at: URL, reason: String)
    }

    /// Where the recording is written until it's mixed: next to `output`, so that a crash leaves a file one can find and play.
    static func unmixedURL(for output: URL) -> URL {
        let name = output.deletingPathExtension().lastPathComponent + "_Unmixed"
        return output.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension(output.pathExtension)
    }

    /// Mixes `unmixed` into `output`, trying once more after `delay`: the first try can fail while the capture is winding down.
    /// If both fail, the unmixed recording takes `output`'s name rather than being left under a name of its own.
    static func finish(unmixed: URL, into output: URL, retryAfter delay: Duration,
                       mix: (URL, URL) async throws -> Void) async -> Outcome {
        let files = FileManager.default
        var reason = ""
        for attempt in 1...2 {
            if attempt > 1 { try? await Task.sleep(for: delay) }
            // A failed try can leave half a file behind
            try? files.removeItem(at: output)
            do {
                try await mix(unmixed, output)
                try? files.removeItem(at: unmixed)
                return .mixed
            } catch {
                reason = String(describing: error)
            }
        }
        try? files.removeItem(at: output)
        do {
            try files.moveItem(at: unmixed, to: output)
            return .keptUnmixed(at: output, reason: reason)
        } catch {
            return .keptUnmixed(at: unmixed, reason: reason)
        }
    }
}

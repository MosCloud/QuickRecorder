//
//  RecordingClock.swift
//  QuickRecorder
//

import Foundation

/// The recording length shown in the menu bar and the capsule.
struct RecordingClock {
    private var startedAt: TimeInterval?
    private var pausedAt: TimeInterval?
    private var pausedTotal: TimeInterval = 0

    mutating func start(at time: TimeInterval) {
        startedAt = time
    }

    mutating func pause(at time: TimeInterval) {
        guard startedAt != nil else { return }
        pausedAt = time
    }

    mutating func resume(at time: TimeInterval) {
        guard let pausedAt else { return }
        pausedTotal += time - pausedAt
        self.pausedAt = nil
    }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        guard let startedAt else { return 0 }
        return (pausedAt ?? time) - startedAt - pausedTotal
    }
}

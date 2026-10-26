//
//  CapsuleDimming.swift
//  QuickRecorder
//

import Foundation

/// Fades the capsule while the pointer is away from it, so it covers less of the screen.
struct CapsuleDimming {
    /// How long the pointer has to be away before the capsule fades.
    static let delay: TimeInterval = 1

    /// Until then the capsule stays fully visible.
    private var holdUntil: TimeInterval
    private var pointerInside = false

    init(emergedAt time: TimeInterval) {
        holdUntil = time + 2
    }

    mutating func pointer(isInside: Bool, at time: TimeInterval) {
        if pointerInside && !isInside { holdUntil = max(holdUntil, time + Self.delay) }
        pointerInside = isInside
    }

    /// Resuming, or the countdown ending: wait a moment before fading, as if the pointer had just left.
    mutating func activity(at time: TimeInterval) {
        holdUntil = max(holdUntil, time + Self.delay)
    }

    func opacity(at time: TimeInterval, idleOpacity: Double, countingDown: Bool, paused: Bool, reduceTransparency: Bool) -> Double {
        let keepFull = pointerInside || time < holdUntil || countingDown || paused || reduceTransparency
        return keepFull ? 1 : idleOpacity
    }
}

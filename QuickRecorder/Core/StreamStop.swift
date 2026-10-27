//
//  StreamStop.swift
//  QuickRecorder
//

import Foundation

/// Why a recording ended on its own (#7): mostly from the error ScreenCaptureKit passed to the stream's delegate.
enum StreamStop: Equatable {
    /// Stop was chosen in the system's screen-recording menu
    case userStopped
    /// The recorded window closed, or the display went off: the lid closed, the Mac slept, a display was unplugged
    case sourceGone
    case systemStopped
    case insufficientStorage
    /// Any other error: its description and code
    case other(String)
    /// Every recorded app quit. The capture carries on regardless, recording nothing, so the app stops it
    case appsQuit

    /// SCStreamErrorDomain, spelled out: Core doesn't link ScreenCaptureKit
    private static let domain = "com.apple.ScreenCaptureKit.SCStreamErrorDomain"

    init(domain: String, code: Int, description: String) {
        switch (domain, code) {
        case (Self.domain, -3817): self = .userStopped
        case (Self.domain, -3815): self = .sourceGone
        case (Self.domain, -3821): self = .systemStopped
        case (Self.domain, -3822): self = .insufficientStorage
        default: self = .other("\(description) (\(code))")
        }
    }
}

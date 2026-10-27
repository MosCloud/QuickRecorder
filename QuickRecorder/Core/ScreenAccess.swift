//
//  ScreenAccess.swift
//  QuickRecorder
//

import Foundation

/// What QuickRecorder does when the system refuses it the screen's content (#5).
enum ScreenAccess {
    enum Reply: Equatable {
        /// Nothing: macOS shows its own prompt, once
        case none
        /// Screen recording is needed: say so, with the way to System Settings
        case explain
        /// Allowed in System Settings, but it takes effect only once QuickRecorder is reopened
        case reopen
    }

    /// `userAsked`: refused while starting a recording, not at launch or in the background.
    /// `allowedInSettings`: what System Settings says, which can differ from what this process is granted.
    static func refused(userAsked: Bool, allowedInSettings: Bool) -> Reply {
        guard userAsked else { return .none }
        return allowedInSettings ? .reopen : .explain
    }
}

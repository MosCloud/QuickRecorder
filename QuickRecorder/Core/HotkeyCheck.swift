//
//  HotkeyCheck.swift
//  QuickRecorder
//

import Foundation

struct HotkeyModifiers: OptionSet, Hashable {
    let rawValue: Int
    static let command = HotkeyModifiers(rawValue: 1 << 0)
    static let option = HotkeyModifiers(rawValue: 1 << 1)
    static let control = HotkeyModifiers(rawValue: 1 << 2)
    static let shift = HotkeyModifiers(rawValue: 1 << 3)
}

/// A global hotkey as the check needs it: the key, its modifiers, and whether the key types a letter or a digit.
struct Hotkey: Equatable {
    var keyCode: Int
    var modifiers: HotkeyModifiers
    var isCharacterKey: Bool
}

/// Decides whether a hotkey may be saved for an action.
enum HotkeyCheck {
    enum Verdict: Equatable {
        case allowed
        /// Another action already has it.
        case usedBy(String)
        /// Other apps use it, so a global hotkey would stop it working everywhere.
        case commonInApps
    }

    /// - Parameter others: the hotkeys of the other actions, with the name the settings show for each.
    static func verdict(for hotkey: Hotkey, others: [(action: String, hotkey: Hotkey)]) -> Verdict {
        if let other = others.first(where: { $0.hotkey.keyCode == hotkey.keyCode && $0.hotkey.modifiers == hotkey.modifiers }) {
            return .usedBy(other.action)
        }
        // ⌘S, ⌘P, ⇧⌘S…: the shortcuts apps are built around
        if hotkey.isCharacterKey && hotkey.modifiers.subtracting(.shift) == .command { return .commonInApps }
        return .allowed
    }
}

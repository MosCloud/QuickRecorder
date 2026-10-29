//
//  PickerEscape.swift
//  QuickRecorder
//

import Foundation

/// What one Esc does in a picker (#153, #155).
///
/// Three layers, each taking the Esc before the one below it: a bubble or the colour window closes first, then the
/// picker's choice is cleared, and only an Esc with nothing chosen closes the picker. Telling them apart is pure logic,
/// so it lives here and the window's key monitor just carries it out.
enum PickerEscape: Equatable {
    /// Not this picker's Esc, or something above it (a bubble, the colour window) wants it
    case passOn
    /// The picker has a choice: clear it and stay open
    case clearChoice
    /// Nothing is chosen: let the window close
    case closePicker
    /// A repeat of a held Esc: swallowed, so holding the key clears once and never closes the picker
    case swallowRepeat

    /// - Parameters:
    ///   - ownWindow: the Esc went to the picker's own window, not to another of QuickRecorder's windows
    ///   - bubbleOpen: a capsule bubble is open, which takes the Esc itself (#95)
    ///   - colourWindowOpen: the custom background's colour window is open, a layer finer than the bubble
    ///   - hasChoice: the picker has at least one screen, app or window chosen
    ///   - isRepeat: the key is being held down
    static func action(ownWindow: Bool, bubbleOpen: Bool, colourWindowOpen: Bool, hasChoice: Bool, isRepeat: Bool) -> Self {
        guard ownWindow else { return .passOn }
        guard !bubbleOpen, !colourWindowOpen else { return .passOn }
        guard !isRepeat else { return .swallowRepeat }
        return hasChoice ? .clearChoice : .closePicker
    }
}

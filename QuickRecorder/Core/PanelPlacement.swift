//
//  PanelPlacement.swift
//  QuickRecorder
//

import Foundation

/// Where the main panel opens (#166).
///
/// The owner picked the lower third in the prototype: the panel's middle sits a third of the screen's height above its
/// bottom edge, centred across it. Not the middle, where it used to sit and where it covered what was being worked on.
enum PanelPlacement {
    /// The distance from the screen's bottom edge to the panel's bottom edge for a panel that has to clear what the
    /// Dock leaves, so a short screen with a tall Dock can't end up with the panel sitting on the Dock
    static let clearance: CGFloat = 24

    /// The panel's bottom-left corner, in the screen's own coordinates
    /// - Parameters:
    ///   - screen: the screen's frame
    ///   - panel: the panel's size
    ///   - visible: what the menu bar and the Dock leave of that screen, in the same space as `screen`
    static func defaultOrigin(screen: CGRect, panel: CGSize, visible: CGRect) -> CGPoint {
        let centred = screen.midX - panel.width / 2
        let aThirdUp = screen.minY + screen.height / 3 - panel.height / 2
        // Only a screen too short for the lower third is pushed up; on the usual screen this changes nothing
        let aboveTheDock = visible.minY + clearance
        return CGPoint(x: centred, y: max(aThirdUp, aboveTheDock))
    }
}

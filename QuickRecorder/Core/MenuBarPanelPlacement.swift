//
//  MenuBarPanelPlacement.swift
//  QuickRecorder
//
//  Where the menu bar panel sits under its status item, and where the arrow points (#179, #181).
//
//  Pure geometry: the panel is a window of our own now, so nothing places it for us the way NSPopover did. Screen
//  coordinates here have the origin at the top left, the way CGWindowList reports a window, so the tests can use the
//  numbers read off the popover this replaces.
//

import Foundation
import CoreGraphics

enum MenuBarPanelPlacement {
    /// The arrow at the panel's top edge, pointing up at the status item
    static let arrowWidth: CGFloat = 26
    static let arrowHeight: CGFloat = 11
    /// The body's corner radius, and the shortest straight runs the arrow may sit on
    static let cornerRadius: CGFloat = 25
    /// Space kept between the panel and the screen's edge when the item is close to one
    static let margin: CGFloat = 8

    struct Result: Equatable {
        /// The window's frame, the arrow included, in the coordinates described above
        var frame: CGRect
        /// The arrow's centre, measured from the window's left edge
        var arrowCentre: CGFloat
    }

    /// - Parameters:
    ///   - content: the panel body's size, the arrow excluded
    ///   - item: the status item's frame, in the screen's coordinates
    ///   - screen: the screen's visible area, the menu bar and the Dock excluded
    static func place(content: CGSize, below item: CGRect, in screen: CGRect) -> Result {
        let size = CGSize(width: max(content.width, 0), height: max(content.height, 0) + arrowHeight)
        var x: CGFloat
        if size.width + 2 * margin <= screen.width {
            // Below the item, kept off the screen's edges
            x = min(max(item.midX - size.width / 2, screen.minX + margin), screen.maxX - margin - size.width)
        } else {
            // Wider than the screen: centre it, the arrow still points at the item when it can
            x = screen.midX - size.width / 2
        }
        // The arrow moves off the item only when the panel had to move off the screen's edge, or when the panel is
        // too narrow for an arrow that clear of its corners
        let straight = cornerRadius + arrowWidth / 2
        var arrow = item.midX - x
        if size.width >= 2 * straight {
            arrow = min(max(arrow, straight), size.width - straight)
        }
        return Result(frame: CGRect(x: x, y: item.maxY, width: size.width, height: size.height), arrowCentre: arrow)
    }
}

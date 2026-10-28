//
//  SizeTag.swift
//  QuickRecorder
//

import Foundation

/// Where the area selector shows the area's size (#110): inside the area, centred just below its top edge, and further
/// down when that would put it under the notch.
enum SizeTag {
    /// Below the area's top edge
    static let inset: CGFloat = 10
    /// Clear of the notch on every side
    static let notchGap: CGFloat = 6

    /// The tag's centre, in the screen's coordinates with the origin at the top left.
    /// - Parameters:
    ///   - area: the selected area.
    ///   - tag: the tag's size.
    ///   - screen: the size of the area's screen.
    ///   - notch: the camera housing on that screen, or nil when it has none.
    static func center(area: CGRect, tag: CGSize, screen: CGSize, notch: CGRect?) -> CGPoint {
        // Only right under the notch does it move down, so beside it the tag may sit in the menu bar
        var top = area.minY + inset
        if hits(notch, tag, x: area.midX, top: top), let notch { top = notch.maxY + notchGap }
        if tag.width + 16 <= area.width && top + tag.height + 8 <= area.maxY {
            return CGPoint(x: area.midX, y: top + tag.height / 2)
        }
        // An area too small to hold it: just outside, above it when there's room clear of the notch, else below
        let x = min(max(area.midX, tag.width / 2 + 4), screen.width - tag.width / 2 - 4)
        let above = area.minY - 8 - tag.height
        if above >= 4 && !hits(notch, tag, x: x, top: above) {
            return CGPoint(x: x, y: above + tag.height / 2)
        }
        return CGPoint(x: x, y: min(area.maxY + 8 + tag.height / 2, screen.height - tag.height / 2 - 4))
    }

    private static func hits(_ notch: CGRect?, _ tag: CGSize, x: CGFloat, top: CGFloat) -> Bool {
        guard let notch else { return false }
        return CGRect(x: x - tag.width / 2, y: top, width: tag.width, height: tag.height).intersects(notch.insetBy(dx: -notchGap, dy: -notchGap))
    }
}

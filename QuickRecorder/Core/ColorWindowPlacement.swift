//
//  ColorWindowPlacement.swift
//  QuickRecorder
//
//  Where the custom background colour window goes (#117): beside the Options bubble that opened it, on the right of
//  it where the screen has room, flipped to the left where it hasn't, and always inside the visible frame.
//

import Foundation

enum ColorWindowPlacement {
    /// `bubble` and the returned frame are screen coordinates with the origin at the bottom left, as AppKit has them.
    /// The window's bottom lines up with the bubble's, `gap` keeps the two panels from touching, and it never leaves
    /// `visible`.
    static func frame(bubble: CGRect, size: CGSize, visible: CGRect, gap: CGFloat = 16) -> CGRect {
        var x = bubble.maxX + gap
        if x + size.width > visible.maxX {
            x = bubble.minX - gap - size.width
        }
        // Neither side has room (a narrow screen, or a bubble filling it): stay on screen as far as possible
        x = min(max(x, visible.minX), max(visible.minX, visible.maxX - size.width))

        var y = bubble.minY
        if y < visible.minY { y = visible.minY }
        if y + size.height > visible.maxY { y = visible.maxY - size.height }

        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}

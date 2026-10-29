//
//  AreaRect.swift
//  QuickRecorder
//

import Foundation

/// The area selector's rectangle (#113): where it starts on a screen it has not seen, what a remembered one becomes
/// on a screen it no longer fits, what changing the size does to the place, and how one screen's rectangle is kept
/// without losing another's.
///
/// Coordinates are the overlay's own: the screen's frame with the origin at its bottom left, the way AppKit has it.
/// The visible frame is in the same space, so it has to be brought there by the caller.
enum AreaRect {
    /// A new screen's rectangle covers this much of the visible frame, in both directions
    static let share: CGFloat = 0.6
    /// Below this the rectangle is awkward to drag, so a small screen gets this much rather than its share
    static let smallest = CGSize(width: 480, height: 270)
    /// Smaller than this a rectangle is a stray click's leftover rather than a choice, and is no memory at all (#131)
    static let smallestUsable = CGSize(width: 20, height: 20)

    /// The rectangle a screen starts with, centred in what the menu bar and the Dock leave of it
    static func initial(visible: CGRect) -> CGRect {
        var size = CGSize(width: (visible.width * share).rounded(.down),
                          height: (visible.height * share).rounded(.down))
        // Enough to drag, but never more than the screen has
        size.width = min(max(size.width, smallest.width), visible.width)
        size.height = min(max(size.height, smallest.height), visible.height)
        return CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// The rectangle a screen remembers, brought inside the screen: a rectangle too big is scaled down around its
    /// middle, one hanging over an edge is moved in, and one with no size at all is no memory at all.
    ///
    /// The screen, not what the menu bar and the Dock leave of it: a rectangle drawn over the menu bar or the Dock was
    /// put there on purpose, to record a menu or a Dock's bounce, and has to come back where it was (#156). Only a
    /// screen's first rectangle has to fit between them, which `initial(visible:)` decides.
    static func restored(_ saved: CGRect?, screen: CGRect, visible: CGRect) -> CGRect {
        guard let saved, saved.width >= smallestUsable.width, saved.height >= smallestUsable.height else {
            return initial(visible: visible)
        }
        var rect = saved
        let fitting = min(1, screen.width / rect.width, screen.height / rect.height)
        if fitting < 1 {
            let middle = CGPoint(x: rect.midX, y: rect.midY)
            rect.size = CGSize(width: (rect.width * fitting).rounded(.down), height: (rect.height * fitting).rounded(.down))
            rect.origin = CGPoint(x: middle.x - rect.width / 2, y: middle.y - rect.height / 2)
        }
        if rect.minX < screen.minX { rect.origin.x = screen.minX }
        if rect.minY < screen.minY { rect.origin.y = screen.minY }
        if rect.maxX > screen.maxX { rect.origin.x = screen.maxX - rect.width }
        if rect.maxY > screen.maxY { rect.origin.y = screen.maxY - rect.height }
        return rect
    }

    /// The rectangle at a new size, still where it was: its middle stays put, and a size the screen can't hold is
    /// cut to the screen (#156: the Edit Area fields offer the screen's own width and height)
    static func resized(_ rect: CGRect, to size: CGSize, screen: CGRect) -> CGRect {
        let width = min(max(size.width, 1), screen.width)
        let height = min(max(size.height, 1), screen.height)
        var new = CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
        if new.minX < screen.minX { new.origin.x = screen.minX }
        if new.minY < screen.minY { new.origin.y = screen.minY }
        if new.maxX > screen.maxX { new.origin.x = screen.maxX - width }
        if new.maxY > screen.maxY { new.origin.y = screen.maxY - height }
        return new
    }

    /// `savedArea` with one screen's rectangle set, the other screens' left alone: recording on one screen used to
    /// throw the rest away
    static func saving(_ existing: [String: [String: CGFloat]], screen: String,
                       rect: CGRect) -> [String: [String: CGFloat]] {
        var all = existing
        all[screen] = ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height]
        return all
    }
}

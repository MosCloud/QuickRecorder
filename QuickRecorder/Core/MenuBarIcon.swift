//
//  MenuBarIcon.swift
//  QuickRecorder
//

import Foundation
import CoreGraphics

/// The menu bar item's idle icon (#186): `record.circle`'s ring, drawn to the same measurements, with the centre dot
/// replaced by a rounded square so it echoes the app icon's square.
///
/// The numbers are the system symbol's own, measured from a 1024 px render of `record.circle` at 14 pt and divided by
/// the 16 pt box it was drawn in: outer diameter 0.849, stroke 0.0703, centre dot 0.326. Keeping them here rather than
/// in the drawing code lets the tests hold the icon to the system's proportions.
enum MenuBarIcon {
    /// The symbol's natural box at the menu bar's text size
    static let box: CGFloat = 16
    /// Outer diameter of the ring, as a share of `box`
    static let ringDiameter: CGFloat = 0.849
    /// The ring's stroke, as a share of `box`
    static let ringStroke: CGFloat = 0.0703
    /// The system's centre dot, as a share of `box`: what the square is sized against
    static let dotDiameter: CGFloat = 0.326
    /// A square of the same side as the dot loses about a fifth of its area, so it is drawn a tenth larger to keep the
    /// icon's visual weight
    static let squareScale: CGFloat = 1.10
    /// The app icon's square is 200 with a 44 corner
    static let squareCorner: CGFloat = 0.22

    /// The ring's radius, measured on its centre line
    static var ringPathRadius: CGFloat { (ringDiameter - ringStroke) / 2 * box }
    static var ringLineWidth: CGFloat { ringStroke * box }
    /// The square's side, and its corner radius
    static var squareSide: CGFloat { dotDiameter * squareScale * box }
    static var squareCornerRadius: CGFloat { squareSide * squareCorner }
}

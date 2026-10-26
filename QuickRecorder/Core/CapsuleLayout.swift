//
//  CapsuleLayout.swift
//  QuickRecorder
//

import Foundation

/// Where the capsule's window sits on screen, and where the capsule is drawn inside it.
struct CapsuleLayout: Equatable {
    /// The window frame in screen coordinates (origin at the bottom left).
    var windowFrame: CGRect
    /// The capsule tucked into the notch, or a hairline at the top of a screen without one.
    /// In the window's coordinates with the origin at the top left, as SwiftUI lays it out.
    var collapsed: CGRect
    /// The capsule hanging below the menu bar, in the same coordinates as `collapsed`.
    var expanded: CGRect

    /// - Parameters:
    ///   - screenFrame: the frame of the screen that shows the capsule.
    ///   - menuBarHeight: the height of that screen's menu bar.
    ///   - notch: the size of the camera housing, or nil when the screen has none.
    ///   - capsule: the size of the expanded capsule.
    static func make(screenFrame: CGRect, menuBarHeight: CGFloat, notch: CGSize?, capsule: CGSize) -> CapsuleLayout {
        // Without a notch, the capsule drops out of a hairline in the middle of the menu bar
        let start = notch ?? CGSize(width: 96, height: 1)
        let top = menuBarHeight + 6
        // Room around the capsule for its shadow and the overshoot of the spring
        let width = max(capsule.width, start.width) + 40
        let height = top + capsule.height + 24
        let windowFrame = CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
        let expanded = CGRect(x: (width - capsule.width) / 2, y: top, width: capsule.width, height: capsule.height)
        let collapsed = CGRect(x: (width - start.width) / 2, y: 0, width: start.width, height: start.height)
        return CapsuleLayout(windowFrame: windowFrame, collapsed: collapsed, expanded: expanded)
    }

    /// Where the pointer counts as being on the expanded capsule, in screen coordinates.
    var hoverArea: CGRect {
        CGRect(x: windowFrame.minX + expanded.minX, y: windowFrame.maxY - expanded.maxY,
               width: expanded.width, height: expanded.height).insetBy(dx: -6, dy: -6)
    }
}

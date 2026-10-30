//
//  MenuBarPanelPlacementTests.swift
//  QuickRecorderTests
//

import Foundation
import Testing

@Suite("Where the menu bar panel sits")
struct MenuBarPanelPlacementTests {
    /// The owner's MacBook Air: 1710×1107, the menu bar 34 pt tall, the Dock hidden. The status item, read from the
    /// popover this replaces: x 995, y 5, 39×24, so its bottom edge is at 29.
    let screen = CGRect(x: 0, y: 34, width: 1710, height: 1073)
    let item = CGRect(x: 995, y: 5, width: 39, height: 24)
    let content = CGSize(width: 310, height: 184)

    @Test("Centred under the item, its top edge at the item's bottom edge, and the arrow in the middle")
    func belowTheItem() {
        let placed = MenuBarPanelPlacement.place(content: content, below: item, in: screen)
        #expect(placed.frame.origin.x == 859.5)        // 1014.5 - 155
        #expect(placed.frame.origin.y == 29)           // the item's bottom edge
        #expect(placed.frame.width == 310)
        #expect(placed.frame.height == 195)            // 184 plus the 11 pt arrow, which is part of the window
        #expect(placed.arrowCentre == 155)             // the item's centre, in the window
    }

    @Test("An item near the left edge pushes the panel in, and the arrow follows as far as its corner allows")
    func leftEdge() {
        let placed = MenuBarPanelPlacement.place(content: content, below: CGRect(x: 0, y: 5, width: 39, height: 24), in: screen)
        #expect(placed.frame.minX == 8)
        #expect(placed.arrowCentre == 38)              // corner radius + half the arrow, not 19.5 - 8
    }

    @Test("An item near the right edge, the same on the other side")
    func rightEdge() {
        let placed = MenuBarPanelPlacement.place(content: content, below: CGRect(x: 1671, y: 5, width: 39, height: 24), in: screen)
        #expect(placed.frame.maxX == 1702)             // 1710 - 8
        #expect(placed.arrowCentre == 272)             // 310 - 38
    }

    @Test("A screen narrower than the panel centres the panel and keeps the arrow on the item")
    func narrowScreen() {
        let narrow = CGRect(x: 0, y: 34, width: 200, height: 100)
        let placed = MenuBarPanelPlacement.place(content: content, below: CGRect(x: 80, y: 5, width: 39, height: 24), in: narrow)
        #expect(placed.frame.midX == 100)              // the screen's centre
        #expect(placed.arrowCentre == 154.5)           // 99.5 - (-55), inside the corners of 310 pt
    }

    @Test("A panel too narrow for the arrow's straight run puts the arrow in the middle")
    func narrowPanel() {
        let placed = MenuBarPanelPlacement.place(content: CGSize(width: 60, height: 30),
                                                 below: CGRect(x: 1000, y: 5, width: 39, height: 24), in: screen)
        #expect(placed.frame.minX == 989.5)            // 1019.5 - 30, the panel is narrow enough to sit under the item
        #expect(placed.arrowCentre == 30)              // half the panel
    }

    @Test("The arrow never reaches into the rounded corners of a panel that has room for it")
    func arrowClearOfCorners() {
        for centre in stride(from: CGFloat(0), through: 1710, by: 37) {
            let placed = MenuBarPanelPlacement.place(content: content, below: CGRect(x: centre, y: 5, width: 39, height: 24), in: screen)
            #expect(placed.arrowCentre >= 38, "item at \(centre)")
            #expect(placed.arrowCentre <= placed.frame.width - 38, "item at \(centre)")
        }
    }

    @Test("A display to the right of another keeps its own coordinates")
    func secondDisplay() {
        let second = CGRect(x: 1710, y: 34, width: 2560, height: 1406)
        let placed = MenuBarPanelPlacement.place(content: content, below: CGRect(x: 2900, y: 5, width: 39, height: 24), in: second)
        #expect(placed.frame.minX == 2764.5)           // 2919.5 - 155, not shifted by the first display
        #expect(placed.arrowCentre == 155)
    }
}

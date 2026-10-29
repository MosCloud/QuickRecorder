//
//  PanelPlacementTests.swift
//  QuickRecorderTests
//

import Foundation
import Testing

@Suite("Where the main panel opens")
struct PanelPlacementTests {
    /// The owner's MacBook Air: 1710×1107, the Dock 82 pt tall, the menu bar 34
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1107)
    let visible = CGRect(x: 0, y: 82, width: 1710, height: 1025)
    let panel = CGSize(width: 768, height: 90)

    @Test("The panel's middle sits a third of the way up, centred across the screen")
    func lowerThird() {
        let origin = PanelPlacement.defaultOrigin(screen: screen, panel: panel, visible: visible)
        #expect(origin.x == 471)                       // (1710 - 768) / 2
        #expect(origin.y == 324)                       // 1107 / 3 - 45
        #expect(origin.y + panel.height / 2 == screen.height / 3)
    }

    @Test("It clears the Dock on a screen too short for the lower third")
    func shortScreen() {
        let short = CGRect(x: 0, y: 0, width: 1440, height: 500)
        let dock = CGRect(x: 0, y: 150, width: 1440, height: 350)
        let origin = PanelPlacement.defaultOrigin(screen: short, panel: panel, visible: dock)
        // The lower third puts the panel's bottom edge at 121.7, below the Dock's 150: the Dock wins
        #expect(origin.y == 174, "got \(origin)")
    }

    @Test("A display to the right of another keeps its own coordinates")
    func secondDisplay() {
        let second = CGRect(x: 1710, y: 0, width: 2560, height: 1440)
        let dock = CGRect(x: 1710, y: 70, width: 2560, height: 1370)
        let origin = PanelPlacement.defaultOrigin(screen: second, panel: panel, visible: dock)
        #expect(origin == CGPoint(x: 2606, y: 435), "got \(origin)")
    }
}

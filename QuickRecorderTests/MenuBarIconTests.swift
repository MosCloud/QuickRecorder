//
//  MenuBarIconTests.swift
//  QuickRecorderTests
//

import Foundation
import Testing

@Suite("The menu bar icon")
struct MenuBarIconTests {
    @Test("The ring keeps the system symbol's own measurements")
    func ringMatchesSystemSymbol() {
        // record.circle at 14 pt: outer 0.849 × 16 = 13.584, stroke 0.0703 × 16 = 1.1248
        #expect(abs(MenuBarIcon.ringDiameter * MenuBarIcon.box - 13.584) < 0.001)
        #expect(abs(MenuBarIcon.ringLineWidth - 1.1248) < 0.001)
        // The stroke is centred on the path, so the path sits half a stroke inside the outer edge
        #expect(abs(MenuBarIcon.ringPathRadius - (13.584 / 2 - 1.1248 / 2)) < 0.001)
    }

    @Test("The square is the system dot's size plus a tenth, and keeps the app icon's corner")
    func squareMatchesDot() {
        // 0.326 × 1.10 × 16 = 5.7376
        #expect(abs(MenuBarIcon.squareSide - 5.7376) < 0.001)
        #expect(abs(MenuBarIcon.squareCornerRadius - 5.7376 * 0.22) < 0.001)
    }

    @Test("The square fits inside the ring with room to spare")
    func squareFitsInsideRing() {
        // The ring's inner edge is the path radius minus half the stroke
        let inner = MenuBarIcon.ringPathRadius - MenuBarIcon.ringLineWidth / 2
        let halfDiagonal = MenuBarIcon.squareSide / 2 * 2.squareRoot()
        #expect(halfDiagonal < inner, "half diagonal \(halfDiagonal) vs inner radius \(inner)")
        // And there is still a clear gap all round, at the menu bar's small size
        #expect(inner - halfDiagonal > 0.3)
    }

    @Test("The square is never round: its corner stays a corner")
    func squareKeepsItsCorners() {
        // A corner radius at or above half the side would be a circle, and the icon would say nothing new
        #expect(MenuBarIcon.squareCornerRadius < MenuBarIcon.squareSide / 2)
        #expect(MenuBarIcon.squareCornerRadius > 0)
    }
}

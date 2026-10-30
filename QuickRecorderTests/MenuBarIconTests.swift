//
//  MenuBarIconTests.swift
//  QuickRecorderTests
//

import Foundation
import Testing

@Suite("The menu bar icon")
struct MenuBarIconTests {
    @Test("The proportions are the system symbol's own")
    func keepsSystemSymbolProportions() {
        // record.circle at 14 pt, in its 16 pt box: outer 0.849, stroke 0.0703, dot 0.326
        #expect(abs(MenuBarIcon.ringDiameter - 0.849) < 0.0001)
        #expect(abs(MenuBarIcon.ringStroke - 0.0703) < 0.0001)
        #expect(abs(MenuBarIcon.dotDiameter - 0.326) < 0.0001)
        // The stroke is centred on the path, so the path sits half a stroke inside the outer edge
        #expect(abs(MenuBarIcon.ringPathRadius - (MenuBarIcon.ringDiameter - MenuBarIcon.ringStroke) / 2 * MenuBarIcon.box) < 0.001)
        #expect(abs(MenuBarIcon.ringLineWidth - MenuBarIcon.ringStroke * MenuBarIcon.box) < 0.001)
    }

    @Test("The icon is drawn a size up from the symbol, because its thin ring reads small")
    func drawnLargerThanSymbol() {
        // The symbol's own box is 16 pt; the icon is 18, and everything scales with it
        #expect(MenuBarIcon.symbolBox == 16)
        #expect(MenuBarIcon.box == 18)
        #expect(abs(MenuBarIcon.ringDiameter * MenuBarIcon.box - 15.282) < 0.001)
        #expect(abs(MenuBarIcon.ringLineWidth - 1.2654) < 0.001)
    }

    @Test("The square is the system dot's size plus a tenth, and keeps the app icon's corner")
    func squareMatchesDot() {
        // 0.326 × 1.10 × 18 = 6.4548
        #expect(abs(MenuBarIcon.squareSide - 6.4548) < 0.001)
        #expect(abs(MenuBarIcon.squareCornerRadius - 6.4548 * 0.22) < 0.001)
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

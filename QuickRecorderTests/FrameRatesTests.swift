//
//  FrameRatesTests.swift
//  QuickRecorderTests
//
//  The frame rates offered for a display (issue #79).
//

import Foundation
import Testing

@Suite("Frame rates by display")
struct FrameRatesTests {
    @Test("A 60 Hz display offers the usual rates up to 60")
    func sixty() {
        #expect(FrameRates.available(maxFPS: 60) == [10, 15, 24, 30, 60])
    }

    @Test("A ProMotion display goes up to 120, a 240 Hz one to 240")
    func faster() {
        #expect(FrameRates.available(maxFPS: 120) == [10, 15, 24, 30, 60, 90, 120])
        #expect(FrameRates.available(maxFPS: 240).last == 240)
    }

    @Test("An unusual refresh rate is offered as the top")
    func unusual() {
        #expect(FrameRates.available(maxFPS: 100) == [10, 15, 24, 30, 60, 90, 100])
        #expect(FrameRates.available(maxFPS: 165).suffix(2) == [144, 165])
    }

    @Test("An unknown refresh rate counts as 60")
    func unknown() {
        #expect(FrameRates.available(maxFPS: 0) == [10, 15, 24, 30, 60])
    }

    @Test("A setting above the display's top rate records at the top rate; one within it, as set")
    func effective() {
        #expect(FrameRates.effective(144, maxFPS: 60) == 60)
        #expect(FrameRates.effective(30, maxFPS: 60) == 30)
        #expect(FrameRates.effective(45, maxFPS: 60) == 45)
        #expect(FrameRates.effective(120, maxFPS: 0) == 60)
    }
}

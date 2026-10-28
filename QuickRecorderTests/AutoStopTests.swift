//
//  AutoStopTests.swift
//  QuickRecorderTests
//
//  The timer that stops a recording after a set time (issue #86).
//

import Foundation
import Testing

@Suite("Stopping a recording after a set time")
struct AutoStopTests {
    @Test("The limit adds up hours, minutes and seconds")
    func limit() {
        #expect(AutoStop(hours: 1, minutes: 2, seconds: 3).limit == 3723)
        #expect(AutoStop(seconds: 30).limit == 30)
        #expect(AutoStop().limit == 0)
    }

    @Test("A recording stops once it reaches the limit, to the second")
    func due() {
        #expect(!AutoStop.isDue(limit: 90, elapsed: 89.5))
        #expect(AutoStop.isDue(limit: 90, elapsed: 90))
    }

    @Test("No limit never stops a recording, and neither does a negative one: -1 used to stop it at once",
          arguments: [0.0, -1, -60])
    func never(limit: TimeInterval) {
        #expect(!AutoStop.isDue(limit: limit, elapsed: 0))
        #expect(!AutoStop.isDue(limit: limit, elapsed: 3600))
    }

    @Test("A number outside its field's range goes back to 0, whichever side it's on")
    func outOfRange() {
        #expect(AutoStop.minuteRange.orZero(-1) == 0)
        #expect(AutoStop.secondRange.orZero(75) == 0)
        #expect(AutoStop.hourRange.orZero(100) == 0)
    }

    @Test("A number inside its range stays, up to the top: hours go well past a day")
    func inRange() {
        #expect(AutoStop.hourRange.orZero(5) == 5)
        #expect(AutoStop.hourRange.orZero(24) == 24)
        #expect(AutoStop.hourRange.orZero(99) == 99)
        #expect(AutoStop.secondRange.orZero(59) == 59)
    }
}

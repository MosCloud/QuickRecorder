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

    @Test("Switching on without a duration takes ten minutes")
    func onWithoutDuration() {
        let next = AutoStop.toggled(on: false, duration: AutoStop())
        #expect(next.on)
        #expect(next.duration == AutoStop(minutes: 10))
    }

    @Test("Switching off keeps the duration, and switching on again uses it")
    func offKeepsDuration() {
        let off = AutoStop.toggled(on: true, duration: AutoStop(seconds: 30))
        #expect(!off.on)
        #expect(off.duration == AutoStop(seconds: 30))
        let on = AutoStop.toggled(on: off.on, duration: off.duration)
        #expect(on.on)
        #expect(on.duration == AutoStop(seconds: 30))
    }

    @Test("Editing the duration doesn't switch the timer on")
    func editKeepsOff() {
        #expect(!AutoStop.staysOn(false, after: AutoStop(minutes: 5)))
        #expect(AutoStop.staysOn(true, after: AutoStop(minutes: 5)))
    }

    @Test("Clearing the duration switches the timer off: a timer of nothing can't run")
    func clearSwitchesOff() {
        #expect(!AutoStop.staysOn(true, after: AutoStop()))
    }

    @Test("A duration round-trips through its seconds, as it is stored")
    func stored() {
        #expect(AutoStop(totalSeconds: 3723) == AutoStop(hours: 1, minutes: 2, seconds: 3))
        #expect(AutoStop(hours: 1, minutes: 2, seconds: 3).totalSeconds == 3723)
    }
}

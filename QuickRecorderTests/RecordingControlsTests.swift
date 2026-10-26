//
//  RecordingControlsTests.swift
//  QuickRecorderTests
//
//  The logic behind the menu bar timer and the notch capsule (issue #1).
//

import Foundation
import Testing

@Suite("Recording clock")
struct RecordingClockTests {
    @Test("Paused spans are left out, and resuming adds no time")
    func pausedSpans() {
        var clock = RecordingClock()
        clock.start(at: 100)
        clock.pause(at: 110)
        #expect(clock.elapsed(at: 113) == 10)
        clock.resume(at: 115)
        #expect(clock.elapsed(at: 120) == 15)
    }

    @Test("Reads zero until the first frame; a pause before it does not count")
    func pauseBeforeFirstFrame() {
        var clock = RecordingClock()
        #expect(clock.elapsed(at: 3) == 0)
        clock.pause(at: 5)
        clock.resume(at: 8)
        clock.start(at: 10)
        #expect(clock.elapsed(at: 12) == 2)
    }
}

@Suite("Control surfaces")
struct ControlSurfacesTests {
    @Test("Each setting shows its own control", arguments: [
        (menuBar: true, capsule: true),
        (menuBar: true, capsule: false),
        (menuBar: false, capsule: true),
    ])
    func eachSetting(menuBar: Bool, capsule: Bool) {
        #expect(ControlSurfaces.whileRecording(menuBar: menuBar, capsule: capsule, statusItemHidden: false)
                == ControlSurfaces(statusItem: menuBar, capsule: capsule))
    }

    @Test("With both settings off, both controls show rather than none")
    func bothOff() {
        #expect(ControlSurfaces.whileRecording(menuBar: false, capsule: false, statusItemHidden: false)
                == ControlSurfaces(statusItem: true, capsule: true))
    }

    @Test("The capsule stands in while the menu bar timer is hidden", arguments: [true, false])
    func hiddenStatusItem(capsule: Bool) {
        #expect(ControlSurfaces.whileRecording(menuBar: true, capsule: capsule, statusItemHidden: true)
                == ControlSurfaces(statusItem: true, capsule: true))
    }
}

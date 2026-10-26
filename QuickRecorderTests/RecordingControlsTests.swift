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

@Suite("Capsule layout")
struct CapsuleLayoutTests {
    // A 13.6" MacBook Air: 1710×1107 points, 34-point menu bar, 185×33.5 notch
    let air = CapsuleLayout.make(screenFrame: CGRect(x: 0, y: 0, width: 1710, height: 1107), menuBarHeight: 34,
                                 notch: CGSize(width: 185, height: 33.5), capsule: CGSize(width: 236, height: 40))

    @Test("Hangs centered 6 points below the menu bar and starts out filling the notch")
    func belowTheNotch() {
        #expect(air.windowFrame == CGRect(x: 717, y: 1003, width: 276, height: 104))
        #expect(air.expanded == CGRect(x: 20, y: 40, width: 236, height: 40))
        #expect(air.collapsed == CGRect(x: 45.5, y: 0, width: 185, height: 33.5))
    }

    @Test("On a screen without a notch it drops from a hairline in the middle of the menu bar")
    func withoutNotch() {
        // A 1920×1080 display to the right of the Air, with a 25-point menu bar
        let external = CapsuleLayout.make(screenFrame: CGRect(x: 1710, y: 0, width: 1920, height: 1080), menuBarHeight: 25,
                                          notch: nil, capsule: CGSize(width: 236, height: 40))
        #expect(external.windowFrame == CGRect(x: 2532, y: 985, width: 276, height: 95))
        #expect(external.expanded == CGRect(x: 20, y: 31, width: 236, height: 40))
        #expect(external.collapsed == CGRect(x: 90, y: 0, width: 96, height: 1))
    }

    @Test("The pointer counts as on the capsule within 6 points of it, in screen coordinates")
    func hoverArea() {
        #expect(air.hoverArea == CGRect(x: 731, y: 1021, width: 248, height: 52))
    }
}

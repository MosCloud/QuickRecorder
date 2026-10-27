//
//  StreamStopTests.swift
//  QuickRecorderTests
//
//  Why the system ended a capture, from the error ScreenCaptureKit reports (issue #7).
//

import Foundation
import Testing

@Suite("Capture ended by the system")
struct StreamStopTests {
    let domain = "com.apple.ScreenCaptureKit.SCStreamErrorDomain"

    @Test("ScreenCaptureKit's codes name the reason", arguments: [
        (code: -3817, stop: StreamStop.userStopped),
        (code: -3815, stop: .sourceGone),
        (code: -3821, stop: .systemStopped),
        (code: -3822, stop: .insufficientStorage),
    ])
    func known(code: Int, stop: StreamStop) {
        #expect(StreamStop(domain: domain, code: code, description: "") == stop)
    }

    @Test("Any other error keeps its code and description, to show and log")
    func other() {
        #expect(StreamStop(domain: domain, code: -3811, description: "capture failed") == .other("capture failed (-3811)"))
        #expect(StreamStop(domain: NSOSStatusErrorDomain, code: -3817, description: "OSStatus") == .other("OSStatus (-3817)"))
    }
}

//
//  OwnWindowsTests.swift
//  QuickRecorderTests
//
//  What a capture filter does with QuickRecorder's own windows (issue #13).
//

import Foundation
import Testing

@Suite("QuickRecorder's own windows in a recording")
struct OwnWindowsTests {
    // Stand-ins for SCRunningApplication and SCWindow
    let app = "QuickRecorder"
    let overlays = ["Camera Overlayer", "Mouse Pointer"]
    let capsule = ["capsule"]
    let opened = ["Area Overlayer"]

    @Test("Hiding itself, QuickRecorder is left out as an app, so popovers and menus it opens later are too; its overlays come back as exceptions")
    func screenHidden() {
        let scope = OwnWindows.screen(hideSelf: true, app: app, overlays: overlays, capsule: capsule, opened: opened)
        #expect(scope.excludedApps == [app])
        #expect(scope.exceptions == overlays)
    }

    @Test("Shown, everything of QuickRecorder is recorded but the capsule")
    func screenShown() {
        let scope = OwnWindows.screen(hideSelf: false, app: app, overlays: overlays, capsule: capsule, opened: opened)
        #expect(scope.excludedApps.isEmpty)
        #expect(scope.exceptions == capsule)
    }

    @Test("An app recording leaves QuickRecorder out of the apps it records, and adds its overlays as exceptions")
    func appsHidden() {
        let scope = OwnWindows.apps(hideSelf: true, app: app, overlays: overlays, capsule: capsule)
        #expect(scope.includedApps.isEmpty)
        #expect(scope.exceptions == overlays)
    }

    @Test("Shown, an app recording takes QuickRecorder in, but the capsule")
    func appsShown() {
        let scope = OwnWindows.apps(hideSelf: false, app: app, overlays: overlays, capsule: capsule)
        #expect(scope.includedApps == [app])
        #expect(scope.exceptions == capsule)
    }

    @Test("Without QuickRecorder among the shareable apps, a screen recording leaves out the windows already open one by one, as before")
    func noApp() {
        let screen = OwnWindows.screen(hideSelf: true, app: nil as String?, overlays: overlays, capsule: capsule, opened: opened)
        #expect(screen.excludedApps.isEmpty)
        #expect(screen.exceptions == opened + capsule)
    }

    @Test("Without QuickRecorder among the shareable apps, an app recording only adds its overlays: an exception it can't hide would show", arguments: [true, false])
    func noAppForApps(hideSelf: Bool) {
        let apps = OwnWindows.apps(hideSelf: hideSelf, app: nil as String?, overlays: overlays, capsule: capsule)
        #expect(apps.includedApps.isEmpty)
        #expect(apps.exceptions == overlays)
    }
}

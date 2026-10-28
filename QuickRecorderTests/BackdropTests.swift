//
//  BackdropTests.swift
//  QuickRecorderTests
//
//  What a recording puts behind what it records (issue #83).
//

import Foundation
import Testing

@Suite("The background behind a recording")
struct BackdropTests {
    @Test("Application recordings use the chosen background")
    func applications() {
        #expect(Backdrop.applies(to: .application))
    }

    @Test("A window recording is the window itself, with no area for a backdrop",
          arguments: [StreamType.window, .windows])
    func windows(type: StreamType) {
        #expect(!Backdrop.applies(to: type))
    }

    @Test("Screen and area recordings show the screen as it is, so a colour picked for an app can't leak into them",
          arguments: [StreamType.screen, .screenarea])
    func screens(type: StreamType) {
        #expect(!Backdrop.applies(to: type))
    }

    @Test("On macOS 27 the desktop picture is WindowManager's \"Wallpaper\" window")
    func windowManager() {
        #expect(Backdrop.isWallpaper(bundleID: "com.apple.WindowManager", title: "Wallpaper"))
    }

    @Test("Older systems drew it in the Dock's windows other than the Dock itself and Launchpad")
    func dock() {
        #expect(Backdrop.isWallpaper(bundleID: "com.apple.dock", title: "Wallpaper-5A1F"))
        #expect(!Backdrop.isWallpaper(bundleID: "com.apple.dock", title: "Dock"))
        #expect(!Backdrop.isWallpaper(bundleID: "com.apple.dock", title: "LPSpringboard"))
    }

    @Test("WindowManager's other windows, and windows without a title, aren't")
    func others() {
        #expect(!Backdrop.isWallpaper(bundleID: "com.apple.WindowManager", title: ""))
        #expect(!Backdrop.isWallpaper(bundleID: "com.apple.WindowManager", title: nil))
        #expect(!Backdrop.isWallpaper(bundleID: "com.apple.finder", title: "Wallpaper"))
    }
}

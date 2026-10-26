//
//  MagnifierCapture.swift
//  QuickRecorder
//

import AppKit
import ScreenCaptureKit

/// Captures the screen area under the pointer for the screen magnifier, leaving out QuickRecorder's own windows.
/// One capture runs at a time; requests arriving meanwhile collapse into the newest one.
@MainActor
final class MagnifierCapture {
    static let shared = MagnifierCapture()
    static let size = NSSize(width: 134, height: 116)

    private var isCapturing = false
    private var pendingPoint: NSPoint?
    private var onImage: ((NSImage) -> Void)?

    /// `point` is in global Cocoa screen coordinates (origin at the bottom left).
    func capture(around point: NSPoint, onImage: @escaping (NSImage) -> Void) {
        self.onImage = onImage
        guard !isCapturing else {
            pendingPoint = point
            return
        }
        isCapturing = true
        Task {
            if let image = await Self.image(around: point) { self.onImage?(image) }
            isCapturing = false
            if let next = pendingPoint, let handler = self.onImage {
                pendingPoint = nil
                capture(around: next, onImage: handler)
            }
        }
    }

    private static func image(around point: NSPoint) async -> NSImage? {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
              let content = SCContext.availableContent,
              let display = content.displays.first(where: { $0.displayID == screen.displayID }) else { return nil }
        // sourceRect is in the display's points with the origin at the top left; keep it inside the display
        let x = min(max(point.x - screen.frame.minX - size.width / 2, 0), screen.frame.width - size.width)
        let y = min(max(screen.frame.maxY - point.y - size.height / 2, 0), screen.frame.height - size.height)
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        config.width = Int(size.width * screen.backingScaleFactor)
        config.height = Int(size.height * screen.backingScaleFactor)
        config.showsCursor = false
        guard let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }
}

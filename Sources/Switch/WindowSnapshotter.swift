import AppKit
import ScreenCaptureKit

enum WindowSnapshotter {
    /// In-memory cache of the most recent thumbnail per window id.
    /// Refreshed on a 1.5s timer while the panel is visible (caller's
    /// responsibility to start/stop). Pre-warming the cache before the
    /// panel opens is what makes the grid feel instant.
    static var cache: [CGWindowID: NSImage] = [:]

    static func snapshot(_ windowID: CGWindowID, force: Bool = false) async -> NSImage? {
        if !force, let hit = cache[windowID] { return hit }
        do {
            let content = try await SCShareableContent.current
            guard let win = content.windows.first(where: { $0.windowID == windowID }) else { return nil }
            let filter = SCContentFilter(desktopIndependentWindow: win)
            let cfg = SCStreamConfiguration()
            cfg.width = Int(win.frame.width)
            cfg.height = Int(win.frame.height)
            cfg.captureResolution = .nominal
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            cache[windowID] = image
            return image
        } catch {
            print("[snapshot] failed for \(windowID): \(error)")
            return nil
        }
    }

    static func prewarm(_ windowIDs: [CGWindowID]) async {
        await withTaskGroup(of: Void.self) { group in
            for id in windowIDs {
                group.addTask { _ = await snapshot(id, force: true) }
            }
        }
    }
}

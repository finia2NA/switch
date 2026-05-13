import AppKit
import ApplicationServices

// Private API used by AltTab and other window managers — gives a direct
// mapping from AXUIElement to CGWindowID. Public AX API has no equivalent,
// so without this we have to fuzzy-match by title or bounds, which fails
// for apps like Chrome that have multiple windows with identical titles.
// Distributed outside the App Store, so private SPI is fine.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

private func axWindowID(_ element: AXUIElement) -> CGWindowID? {
    var id: CGWindowID = 0
    let err = _AXUIElementGetWindow(element, &id)
    return err == .success ? id : nil
}

enum WindowFocuser {
    /// AX-raise FIRST, then activate the app. Reverse order loses races on
    /// macOS 14+/26 because `.accessory` apps requesting cross-app activation
    /// gets denied intermittently — picker dismisses, no switch happens.
    /// AX-raise works regardless of activation state, so by the time activate
    /// runs, the right window is already main and the system honors it.
    static func focus(_ window: WindowInfo) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        if app?.isHidden == true { app?.unhide() }

        let appAX = AXUIElementCreateApplication(window.pid)
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(appAX, kAXWindowsAttribute as CFString, &ref) == .success,
           let axWindows = ref as? [AXUIElement],
           let target = bestMatch(for: window, in: axWindows) ?? axWindows.first {
            AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        }

        app?.activate(options: [])

        WindowMRU.touch(window.id)
    }

    /// Direct CGWindowID match via private SPI. Title and bounds matching
    /// both fail for Chrome (identical titles + shadow padding throws bounds
    /// off). This is the ID the OS itself uses, so it's exact.
    private static func bestMatch(for window: WindowInfo, in axWindows: [AXUIElement]) -> AXUIElement? {
        if let exact = axWindows.first(where: { axWindowID($0) == window.id }) {
            return exact
        }
        // Fallbacks if the SPI failed for some element (rare).
        var bestByBounds: (element: AXUIElement, distance: CGFloat)?
        for ax in axWindows {
            guard let frame = AXHelpers.frame(of: ax) else { continue }
            let d = abs(frame.origin.x - window.bounds.origin.x)
                  + abs(frame.origin.y - window.bounds.origin.y)
                  + abs(frame.size.width  - window.bounds.size.width)
                  + abs(frame.size.height - window.bounds.size.height)
            if bestByBounds == nil || d < bestByBounds!.distance {
                bestByBounds = (ax, d)
            }
        }
        if let bestByBounds, bestByBounds.distance < 40 { return bestByBounds.element }
        return axWindows.first(where: { AXHelpers.title(of: $0) == window.title })
    }
}

enum AppCloser {
    static func close(_ window: WindowInfo) {
        NSRunningApplication(processIdentifier: window.pid)?.terminate()
    }
}

enum WindowCloser {
    /// Sends a close action to the AX window matching `window`. Best-effort.
    static func close(_ window: WindowInfo) {
        let appAX = AXUIElementCreateApplication(window.pid)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appAX, kAXWindowsAttribute as CFString, &ref) == .success,
              let axWindows = ref as? [AXUIElement] else { return }

        // Direct CGWindowID match via private SPI, same as focus. Title
        // matching alone closed the wrong Chrome window when titles collided.
        let exact = axWindows.first(where: { axWindowID($0) == window.id })
        let target = exact
            ?? axWindows.first(where: { AXHelpers.title(of: $0) == window.title })
            ?? axWindows.first
        guard let target else { return }
        var btnRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target, kAXCloseButtonAttribute as CFString, &btnRef) == .success,
              let btnObj = btnRef else { return }
        let closeBtn = btnObj as! AXUIElement
        AXUIElementPerformAction(closeBtn, kAXPressAction as CFString)
    }
}

enum AXHelpers {
    static func title(of element: AXUIElement) -> String {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &ref)
        return ref as? String ?? ""
    }

    /// AX position + size as a CGRect, or nil if either attribute is missing.
    /// Used to disambiguate windows when titles collide (e.g. Chrome).
    static func frame(of element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }
        guard let posObj = posRef, let sizeObj = sizeRef else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posObj as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeObj as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }
}

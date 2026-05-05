import AppKit
import CoreGraphics

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let bounds: CGRect
    var isCrossSpace: Bool = false
}

enum WindowEnumerator {
    private static let skipApps: Set<String> = [
        "Window Server", "Dock", "SystemUIServer", "Control Center",
        "Notification Center", "Spotlight", "WallpaperAgent", "Switch",
        "loginwindow", "talagent", "TextInputMenuAgent", "TextInputSwitcher",
        "universalControl", "ControlStrip", "ScreenshotCapture"
    ]

    private static let helperSuffixes: [String] = [
        "Helper", " Helper", " Helper (Renderer)", " Helper (GPU)", " Helper (Plugin)",
        "Agent", " Agent",
        "Service", " Service", " View Service",
        "Renderer", "(Renderer)",
        "WebContent", "Networking",
        "Extension"
    ]

    private static func isHelperProcess(_ name: String) -> Bool {
        for s in helperSuffixes where name.hasSuffix(s) { return true }
        return false
    }

    struct Enumeration {
        let activeSpace: [WindowInfo]
        let crossSpace: [WindowInfo]
    }

    static func currentWindows(scope: HotkeyManager.Mode, frontmostPID: pid_t?) -> [WindowInfo] {
        let e = enumerate(scope: scope, frontmostPID: frontmostPID)
        return e.activeSpace + e.crossSpace
    }

    static func enumerate(scope: HotkeyManager.Mode, frontmostPID: pid_t?) -> Enumeration {
        let activeSpace = enumerate(option: [.optionOnScreenOnly, .excludeDesktopElements], scope: scope, frontmostPID: frontmostPID)

        // UserDefaults read direct — SwitchPreferences is @MainActor and this
        // static func runs from prewarm background queues.
        let showCross = (UserDefaults.standard.object(forKey: "switch.showCrossSpace") as? Bool) ?? true
        guard showCross else {
            return Enumeration(activeSpace: activeSpace, crossSpace: [])
        }

        let everything = enumerate(option: [.optionAll, .excludeDesktopElements], scope: scope, frontmostPID: frontmostPID)
        let activeIDs = Set(activeSpace.map { $0.id })
        let crossSpace = everything
            .filter { !activeIDs.contains($0.id) }
            .map { var w = $0; w.isCrossSpace = true; return w }
        return Enumeration(activeSpace: activeSpace, crossSpace: crossSpace)
    }

    private static func enumerate(option: CGWindowListOption, scope: HotkeyManager.Mode, frontmostPID: pid_t?) -> [WindowInfo] {
        guard let raw = CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var out: [WindowInfo] = []
        var seen: Set<String> = []
        for d in raw {
            let appName = d[kCGWindowOwnerName as String] as? String ?? ""
            // Diagnostic log for the reported Chrome-windows-not-appearing bug.
            // Console.app filter: subsystem=Switch, prefix [chrome-debug].
            if appName.lowercased().contains("chrome") {
                let layer = d[kCGWindowLayer as String] as? Int ?? -999
                let alpha = d[kCGWindowAlpha as String] as? Double ?? -1
                let title = d[kCGWindowName as String] as? String ?? ""
                let bd = d[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
                NSLog("[chrome-debug] app='\(appName)' layer=\(layer) alpha=\(alpha) title='\(title)' bounds=\(Int(bd["Width"] ?? 0))x\(Int(bd["Height"] ?? 0))")
            }

            guard let layer = d[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let alpha = d[kCGWindowAlpha as String] as? Double, alpha > 0 else { continue }
            guard let id = d[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let pid = d[kCGWindowOwnerPID as String] as? pid_t else { continue }
            if skipApps.contains(appName) { continue }
            if isHelperProcess(appName) { continue }
            let title = d[kCGWindowName as String] as? String ?? ""
            let boundsDict = d[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            if bounds.width < 100 || bounds.height < 80 { continue }
            if title.isEmpty && (bounds.width < 400 || bounds.height < 300) { continue }
            let dedupeKey = "\(pid):\(title):\(Int(bounds.width))x\(Int(bounds.height))"
            if seen.contains(dedupeKey) { continue }
            seen.insert(dedupeKey)
            if scope == .currentApp, let f = frontmostPID, pid != f { continue }
            out.append(WindowInfo(id: id, pid: pid, appName: appName, title: title, bounds: bounds))
        }
        return out
    }
}

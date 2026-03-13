import AppKit

struct WindowInfo {
    let id: CGWindowID
    let title: String
    let pid: pid_t
    let ownerName: String
}

enum WindowEnumerator {
    static func list() -> [WindowInfo] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap { dict in
            // Only normal-layer windows (0). Menu bar is layer 25, Dock is 20, etc.
            let layer = (dict[kCGWindowLayer as String] as? Int) ?? -1
            guard layer == 0 else { return nil }

            guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
                  let pid = dict[kCGWindowOwnerPID as String] as? pid_t else { return nil }
            let title = (dict[kCGWindowName as String] as? String) ?? ""
            // Drop windows that have no title — usually system/helper windows.
            guard !title.isEmpty else { return nil }
            let owner = (dict[kCGWindowOwnerName as String] as? String) ?? ""
            return WindowInfo(id: id, title: title, pid: pid, ownerName: owner)
        }
    }
}

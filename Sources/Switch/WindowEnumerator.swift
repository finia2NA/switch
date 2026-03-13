import AppKit

struct WindowInfo {
    let id: CGWindowID
    let title: String
    let pid: pid_t
}

enum WindowEnumerator {
    static func list() -> [WindowInfo] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap { dict in
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
                  let pid = dict[kCGWindowOwnerPID as String] as? pid_t else { return nil }
            let title = (dict[kCGWindowName as String] as? String) ?? ""
            // FIXME: getting menu bar items + Dock + system overlays in here
            return WindowInfo(id: id, title: title, pid: pid)
        }
    }
}

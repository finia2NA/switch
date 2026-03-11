import AppKit

struct WindowInfo {
    let id: CGWindowID
    let title: String
    let pid: pid_t
}

enum WindowEnumerator {
    static func list() -> [WindowInfo] {
        return []
    }
}

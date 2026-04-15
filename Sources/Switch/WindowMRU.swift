import Foundation

final class WindowMRU {
    private var order: [CGWindowID] = []

    func touch(_ id: CGWindowID) {
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
    }

    /// Seed from the OS-provided window list — used on first open before any
    /// touches have been recorded. Without this the order on first cmd-tab is
    /// undefined (insertion order from CGWindowListCopyWindowInfo).
    func seedIfEmpty(_ windows: [WindowInfo]) {
        guard order.isEmpty else { return }
        order = windows.map { $0.id }
    }

    func sort(_ windows: [WindowInfo]) -> [WindowInfo] {
        let positions = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return windows.sorted { (a, b) -> Bool in
            let pa = positions[a.id] ?? Int.max
            let pb = positions[b.id] ?? Int.max
            return pa < pb
        }
    }
}

import Foundation
import Combine

final class SwitchModel: ObservableObject {
    @Published private(set) var windows: [WindowInfo] = []
    @Published var selected: Int = 0

    func refresh() {
        let t = CFAbsoluteTimeGetCurrent()
        windows = WindowEnumerator.list()
        print("[model] refresh \(windows.count) windows in \((CFAbsoluteTimeGetCurrent() - t) * 1000)ms")
        if selected >= windows.count { selected = 0 }
    }

    func advance() {
        guard !windows.isEmpty else { return }
        selected = (selected + 1) % windows.count
    }

    func back() {
        guard !windows.isEmpty else { return }
        selected = (selected - 1 + windows.count) % windows.count
    }
}

import AppKit

final class HotkeyManager {
    private var monitor: Any?

    func install() {
        // Try NSEvent global monitor first — simplest API.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            if event.modifierFlags.contains(.command) && event.keyCode == 48 { // 48 = Tab
                print("cmd-tab detected")
            }
        }
    }
}

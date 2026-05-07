import SwiftUI

@main
struct SwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Settings scene reserved at App level only to satisfy the body
    // requirement and avoid spawning a default window on launch. The actual
    // settings UI opens via SettingsWindow.show() from the menu bar item,
    // which manages its own NSWindow because SwiftUI's Settings doesn't
    // reliably show on .accessory apps in macOS 14+.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

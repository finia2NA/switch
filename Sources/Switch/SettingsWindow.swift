import AppKit
import SwiftUI

/// Manual settings window. SwiftUI's `Settings { }` scene is unreliable
/// on `.accessory` apps, so we host `SettingsView` in our own NSWindow.
///
/// Activation pattern: switch the app's policy from `.accessory` to `.regular`
/// while the settings window is open, then revert on close. This is what
/// menu-bar utilities like Rectangle and Hyperkey do, and is the only
/// reliable way to bring a window to the foreground from an accessory app
/// on macOS 14+, where `NSApp.activate(ignoringOtherApps:)` was deprecated
/// and silently no-ops in some configurations.
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?

    private init() {}

    func show() {
        // Promote to .regular so the window can take focus reliably.
        // The Dock icon flickers on briefly; reverts on close.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        if let existing = window {
            NSApp.activate()
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }

        let host = NSHostingController(rootView: SettingsView())
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Switch Settings"
        win.contentViewController = host
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = SettingsWindowDelegate.shared

        window = win
        NSApp.activate()
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }

    func handleClose() {
        window = nil
        // Revert to .accessory so we go back to menu-bar-only.
        // Slight delay so the close animation finishes cleanly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            SettingsWindow.shared.handleClose()
        }
    }
}

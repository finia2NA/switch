import AppKit
import ApplicationServices
import Combine
import ScreenCaptureKit

@MainActor
final class OnboardingModel: ObservableObject {
    @Published private(set) var hasAccessibility = false
    @Published private(set) var hasScreenRecording = false

    private var pollTimer: Timer?

    var allGranted: Bool { hasAccessibility && hasScreenRecording }

    func startPolling() {
        check()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func check() {
        hasAccessibility = AXIsProcessTrusted()
        Task {
            do {
                _ = try await SCShareableContent.current
                await MainActor.run { self.hasScreenRecording = true }
            } catch {
                await MainActor.run { self.hasScreenRecording = false }
            }
        }
    }

    func openAccessibilityPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openScreenRecordingPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

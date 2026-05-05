import Foundation
import ApplicationServices
import AppKit
import Combine

final class PermissionsManager: ObservableObject {
    @Published private(set) var isAccessibilityGranted: Bool = false

    private var pollTimer: Timer?

    init() {
        refresh()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Re-checks the system trust state without prompting.
    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isAccessibilityGranted {
            DispatchQueue.main.async { self.isAccessibilityGranted = trusted }
        }
    }

    /// Asks the system to show the Accessibility prompt for this app the first time.
    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    /// Opens System Settings directly to the Accessibility pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
}

import Foundation
import Combine
import SwiftUI
import AppKit
import CoreGraphics

final class AppState: ObservableObject {
    @Published var settings: Settings
    @Published var hotkeyError: String?
    @Published var capturingPoint: Bool = false
    @Published var captureCountdown: Int = 0

    let engine: ClickEngine
    let permissions: PermissionsManager

    private var cancellables = Set<AnyCancellable>()
    private var captureTimer: Timer?

    init() {
        let loaded = Settings.load()
        self.settings = loaded
        self.engine = ClickEngine()
        self.permissions = PermissionsManager()

        engine.updateSettings(loaded)

        // Persist + propagate setting changes (debounced so a slider drag doesn't thrash UserDefaults).
        $settings
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] settings in
                settings.save()
                self?.engine.updateSettings(settings)
            }
            .store(in: &cancellables)

        // Forward child ObservableObject changes through AppState so any view that
        // observes AppState (via @EnvironmentObject) re-renders when engine state
        // or permission state changes.
        engine.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        permissions.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Wire global hotkey -> engine toggle.
        HotkeyManager.shared.onTrigger = { [weak self] in
            self?.engine.toggle()
        }
        if !HotkeyManager.shared.register(settings.hotkey) {
            hotkeyError = "Could not register hotkey \(KeycodeMap.displayName(for: settings.hotkey)). Try a different combination."
        }
    }

    /// Replace the registered hotkey. Reverts to the previous one on failure.
    func setHotkey(_ config: HotkeyConfig) {
        let previous = settings.hotkey
        if HotkeyManager.shared.register(config) {
            settings.hotkey = config
            hotkeyError = nil
        } else {
            hotkeyError = "Could not register \(KeycodeMap.displayName(for: config)). Try a different combination."
            _ = HotkeyManager.shared.register(previous)
        }
    }

    /// Capture the cursor's current location after a countdown so the user can position it.
    func captureCursorPosition(after delaySeconds: Int = 3) {
        guard !capturingPoint else { return }
        capturingPoint = true
        captureCountdown = delaySeconds
        captureTimer?.invalidate()
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.captureCountdown -= 1
            if self.captureCountdown <= 0 {
                timer.invalidate()
                let pos = CGEvent(source: nil)?.location ?? .zero
                let point = ClickPoint(point: pos, label: "Point \(self.settings.points.count + 1)")
                self.settings.points.append(point)
                self.capturingPoint = false
            }
        }
    }

    func cancelCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        capturingPoint = false
        captureCountdown = 0
    }

    func addManualPoint(x: Double, y: Double) {
        let p = ClickPoint(point: CGPoint(x: x, y: y),
                           label: "Point \(settings.points.count + 1)")
        settings.points.append(p)
    }

    func removePoint(_ point: ClickPoint) {
        settings.points.removeAll { $0.id == point.id }
    }

    func updatePointLabel(_ point: ClickPoint, label: String) {
        guard let idx = settings.points.firstIndex(where: { $0.id == point.id }) else { return }
        settings.points[idx].label = label
    }

    func resetClickCount() { engine.resetCount() }
}

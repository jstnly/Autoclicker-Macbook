import Foundation
import CoreGraphics
import AppKit
import Combine

/// Performs the actual clicking. All real state lives on a dedicated GCD queue so
/// SwiftUI updates and the high-rate click loop do not block each other.
final class ClickEngine: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var clickCount: Int = 0

    private struct Snapshot {
        var cps: Double = 10.0
        var mode: ClickMode = .followCursor
        var button: MouseButton = .left
        var points: [CGPoint] = []
        var jitterPercent: Double = 0.0
        var downUpGapMs: Int = 0
        var restoreCursorAfterCycle: Bool = false
    }

    private let queue = DispatchQueue(label: "com.user.autoclicker.engine", qos: .userInteractive)
    private var timer: DispatchSourceTimer?     // queue-only
    private var source: CGEventSource?          // queue-only
    private var snap = Snapshot()               // queue-only

    private let countLock = NSLock()
    private var pendingCount: Int = 0
    private var countPublishTimer: Timer?       // main-only

    private var sleepObservers: [NSObjectProtocol] = []

    init() {
        registerSleepHandlers()
    }

    deinit {
        timer?.cancel()
        for o in sleepObservers { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Public API

    func updateSettings(_ settings: Settings) {
        let new = Snapshot(
            cps: max(0.1, settings.cps),
            mode: settings.mode,
            button: settings.button,
            points: settings.points.map { $0.cgPoint },
            jitterPercent: max(0, min(50, settings.jitterPercent)),
            downUpGapMs: max(0, min(500, settings.downUpGapMs)),
            restoreCursorAfterCycle: settings.restoreCursorAfterCycle
        )
        queue.async { [weak self] in
            guard let self = self else { return }
            let wasRunning = self.timer != nil
            self.snap = new
            if wasRunning { self.scheduleTimer() }
        }
    }

    func start() { queue.async { [weak self] in self?.startOnQueue() } }
    func stop()  { queue.async { [weak self] in self?.stopOnQueue() } }

    func toggle() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.timer != nil { self.stopOnQueue() } else { self.startOnQueue() }
        }
    }

    func resetCount() {
        countLock.lock()
        pendingCount = 0
        countLock.unlock()
        DispatchQueue.main.async { self.clickCount = 0 }
    }

    // MARK: - Queue-only

    private func startOnQueue() {
        guard timer == nil else { return }
        if snap.mode == .fixedPoints && snap.points.isEmpty { return }
        if source == nil { source = CGEventSource(stateID: .hidSystemState) }
        scheduleTimer()
        DispatchQueue.main.async {
            self.isRunning = true
            self.startCountPublisher()
        }
    }

    private func stopOnQueue() {
        timer?.cancel()
        timer = nil
        // Safety: if we somehow left a Down without an Up, push an Up at the cursor.
        if let src = source {
            let pos = CGEvent(source: nil)?.location ?? .zero
            postMouseEvent(type: snap.button == .left ? .leftMouseUp : .rightMouseUp,
                           at: pos, button: snap.button, source: src)
        }
        DispatchQueue.main.async {
            self.isRunning = false
            self.countPublishTimer?.invalidate()
            self.countPublishTimer = nil
            self.flushCount()
        }
    }

    private func scheduleTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        let interval = 1.0 / snap.cps
        let ns = max(1, Int(interval * 1_000_000_000))
        t.schedule(deadline: .now() + .milliseconds(20),
                   repeating: .nanoseconds(ns),
                   leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    private func tick() {
        guard let src = source else { return }
        let originalPos = snap.restoreCursorAfterCycle ? CGEvent(source: nil)?.location : nil

        switch snap.mode {
        case .followCursor:
            let pos = CGEvent(source: nil)?.location ?? .zero
            performClickPair(at: pos, button: snap.button, gapMs: snap.downUpGapMs, source: src)
            incrementCount(by: 1)

        case .fixedPoints:
            guard !snap.points.isEmpty else { return }
            for p in snap.points {
                postMouseEvent(type: .mouseMoved, at: p, button: snap.button, source: src)
                performClickPair(at: p, button: snap.button, gapMs: snap.downUpGapMs, source: src)
            }
            incrementCount(by: snap.points.count)
            if let original = originalPos {
                postMouseEvent(type: .mouseMoved, at: original, button: snap.button, source: src)
            }
        }

        // Optional jitter — bounded sleep on our dedicated queue.
        if snap.jitterPercent > 0 {
            let interval = 1.0 / snap.cps
            let maxJitter = interval * (snap.jitterPercent / 100.0)
            let j = Double.random(in: 0...maxJitter)
            if j > 0 { Thread.sleep(forTimeInterval: j) }
        }
    }

    private func performClickPair(at point: CGPoint, button: MouseButton, gapMs: Int, source: CGEventSource) {
        let down: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let up:   CGEventType = button == .left ? .leftMouseUp   : .rightMouseUp
        postMouseEvent(type: down, at: point, button: button, source: source)
        if gapMs > 0 { Thread.sleep(forTimeInterval: Double(gapMs) / 1000.0) }
        postMouseEvent(type: up, at: point, button: button, source: source)
    }

    private func postMouseEvent(type: CGEventType, at point: CGPoint, button: MouseButton, source: CGEventSource) {
        let cgButton: CGMouseButton = button == .left ? .left : .right
        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: point,
                                  mouseButton: cgButton)
        else { return }
        switch type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            // Without click state == 1, many games treat the events as a drag and ignore them.
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        default:
            break
        }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Count throttling for SwiftUI

    private func incrementCount(by n: Int) {
        countLock.lock()
        pendingCount += n
        countLock.unlock()
    }

    private func startCountPublisher() {
        DispatchQueue.main.async {
            self.countPublishTimer?.invalidate()
            self.countPublishTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.flushCount()
            }
        }
    }

    private func flushCount() {
        countLock.lock()
        let n = pendingCount
        pendingCount = 0
        countLock.unlock()
        if n > 0 {
            DispatchQueue.main.async { self.clickCount += n }
        }
    }

    // MARK: - Sleep handling

    private func registerSleepHandlers() {
        let nc = NSWorkspace.shared.notificationCenter
        let willSleep = nc.addObserver(forName: NSWorkspace.willSleepNotification,
                                       object: nil, queue: .main) { [weak self] _ in self?.stop() }
        let screensSleep = nc.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                          object: nil, queue: .main) { [weak self] _ in self?.stop() }
        sleepObservers = [willSleep, screensSleep]
    }
}

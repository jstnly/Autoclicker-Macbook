import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @State private var showingHotkeyRecorder = false
    @State private var showAdvanced = false
    @State private var manualX: String = ""
    @State private var manualY: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatusHeader()
                PermissionBanner()

                if let err = appState.hotkeyError {
                    Banner(text: err, kind: .warning)
                }

                Divider()

                SpeedSection()
                MouseButtonSection()
                ModeSection()

                if appState.settings.mode == .fixedPoints {
                    FixedPointsSection(manualX: $manualX, manualY: $manualY)
                }

                HotkeySection(showingRecorder: $showingHotkeyRecorder)

                DisclosureGroup(isExpanded: $showAdvanced) {
                    AdvancedSection().padding(.top, 8)
                } label: {
                    Text("Advanced").font(.headline)
                }

                Spacer(minLength: 8)

                StartStopButton()
            }
            .padding(20)
        }
        .frame(minWidth: 440, idealWidth: 460, maxWidth: 520,
               minHeight: 600, idealHeight: 640)
        .sheet(isPresented: $showingHotkeyRecorder) {
            HotkeyRecorderView(isPresented: $showingHotkeyRecorder)
                .environmentObject(appState)
        }
    }
}

// MARK: - Status

private struct StatusHeader: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow.click.2")
                .font(.title2)
            Text("Autoclicker")
                .font(.title2.bold())

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(appState.engine.isRunning ? Color.green : Color.secondary)
                    .frame(width: 10, height: 10)
                Text(appState.engine.isRunning ? "Running" : "Stopped")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("\(appState.engine.clickCount) clicks")
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.secondary)

            Button {
                appState.resetClickCount()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Reset click count")
        }
    }
}

// MARK: - Permissions

private struct PermissionBanner: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.permissions.isAccessibilityGranted {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Accessibility permission required")
                        .font(.headline)
                }
                Text("macOS will not let this app post mouse events until you enable it under Privacy & Security › Accessibility.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Button("Open Accessibility Settings") {
                        appState.permissions.openAccessibilitySettings()
                    }
                    Button("Request Permission") {
                        appState.permissions.requestAccess()
                    }
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.6), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct Banner: View {
    enum Kind { case warning, info }
    let text: String
    let kind: Kind

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundColor(kind == .warning ? .orange : .accentColor)
            Text(text).font(.callout)
            Spacer()
        }
        .padding(10)
        .background((kind == .warning ? Color.orange : Color.accentColor).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Speed

private struct SpeedSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speed").font(.headline)
                Spacer()
                Text("\(intervalLabel) per click")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            HStack {
                Slider(
                    value: Binding(
                        get: { appState.settings.cps },
                        set: { appState.settings.cps = (($0 * 10).rounded()) / 10 }
                    ),
                    in: 1...100,
                    step: 1
                )
                TextField("", value: Binding(
                    get: { appState.settings.cps },
                    set: { appState.settings.cps = max(0.1, min(1000, $0)) }
                ), format: .number.precision(.fractionLength(0...1)))
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                Text("CPS").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var intervalLabel: String {
        let cps = max(0.1, appState.settings.cps)
        let ms = 1000.0 / cps
        if ms >= 1000 {
            return String(format: "%.2f s", ms / 1000)
        } else if ms >= 10 {
            return String(format: "%.0f ms", ms)
        } else {
            return String(format: "%.1f ms", ms)
        }
    }
}

// MARK: - Mouse button

private struct MouseButtonSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mouse Button").font(.headline)
            Picker("", selection: $appState.settings.button) {
                ForEach(MouseButton.allCases) { b in
                    Text(b.displayName).tag(b)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

// MARK: - Mode

private struct ModeSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Click Target").font(.headline)
            Picker("", selection: $appState.settings.mode) {
                ForEach(ClickMode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(modeHint)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var modeHint: String {
        switch appState.settings.mode {
        case .followCursor:
            return "Clicks happen wherever the mouse cursor currently is."
        case .fixedPoints:
            return "Each cycle clicks every saved location in order."
        }
    }
}

// MARK: - Fixed points

private struct FixedPointsSection: View {
    @EnvironmentObject var appState: AppState
    @Binding var manualX: String
    @Binding var manualY: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Locations").font(.headline)
                Spacer()
                Text("\(appState.settings.points.count) saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if appState.settings.points.isEmpty {
                Text("No locations yet. Capture the cursor's position or add coordinates manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                VStack(spacing: 4) {
                    ForEach(appState.settings.points) { point in
                        PointRow(point: point)
                    }
                }
            }

            HStack(spacing: 8) {
                if appState.capturingPoint {
                    Button("Cancel (\(appState.captureCountdown))") {
                        appState.cancelCapture()
                    }
                } else {
                    Button {
                        appState.captureCursorPosition()
                    } label: {
                        Label("Capture Cursor (3s)", systemImage: "scope")
                    }
                }

                Spacer()

                TextField("X", text: $manualX)
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                TextField("Y", text: $manualY)
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    if let x = Double(manualX), let y = Double(manualY) {
                        appState.addManualPoint(x: x, y: y)
                        manualX = ""
                        manualY = ""
                    }
                }
                .disabled(Double(manualX) == nil || Double(manualY) == nil)
            }
        }
    }
}

private struct PointRow: View {
    @EnvironmentObject var appState: AppState
    let point: ClickPoint

    @State private var label: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundColor(.accentColor)
            Text(String(format: "%.0f, %.0f", point.x, point.y))
                .font(.subheadline.monospacedDigit())
                .frame(width: 110, alignment: .leading)
            TextField("Label (optional)", text: $label)
                .textFieldStyle(.roundedBorder)
                .onAppear { label = point.label }
                .onChange(of: label) { newValue in
                    appState.updatePointLabel(point, label: newValue)
                }
            Button {
                appState.removePoint(point)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove this location")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Hotkey

private struct HotkeySection: View {
    @EnvironmentObject var appState: AppState
    @Binding var showingRecorder: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Toggle Hotkey").font(.headline)
            HStack {
                Text(KeycodeMap.displayName(for: appState.settings.hotkey))
                    .font(.title3.monospaced())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
                Button("Change…") { showingRecorder = true }
            }
            Text("Works system-wide, including in fullscreen games.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Advanced

private struct AdvancedSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Jitter")
                    Spacer()
                    Text("\(Int(appState.settings.jitterPercent))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: $appState.settings.jitterPercent, in: 0...50, step: 1)
                Text("Randomizes the click interval. Helps with games that detect perfectly periodic input.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Down → Up gap")
                    Spacer()
                    Text("\(appState.settings.downUpGapMs) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(appState.settings.downUpGapMs) },
                        set: { appState.settings.downUpGapMs = Int($0) }
                    ),
                    in: 0...200, step: 1
                )
                Text("Some games ignore zero-duration clicks. 30–80 ms emulates a human press.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("Restore cursor after each cycle (fixed-locations mode only)",
                   isOn: $appState.settings.restoreCursorAfterCycle)
        }
    }
}

// MARK: - Start / Stop

private struct StartStopButton: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button {
            appState.engine.toggle()
        } label: {
            HStack {
                Image(systemName: appState.engine.isRunning ? "stop.circle.fill" : "play.circle.fill")
                Text(appState.engine.isRunning
                     ? "Stop"
                     : "Start  (\(KeycodeMap.displayName(for: appState.settings.hotkey)))")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(appState.engine.isRunning ? .red : .accentColor)
        .disabled(!appState.permissions.isAccessibilityGranted ||
                  (appState.settings.mode == .fixedPoints && appState.settings.points.isEmpty))
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorderView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var recordedKey: UInt32?
    @State private var recordedMods: UInt32 = 0
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 16) {
            Text("Set New Hotkey").font(.headline)

            Text(displayText)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .frame(width: 240, height: 64)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Hold modifier keys (⌃ ⌥ ⇧ ⌘) and press a key. Press Esc to cancel.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(recordedKey == nil)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear { startMonitor() }
        .onDisappear { stopMonitor() }
    }

    private var displayText: String {
        guard let key = recordedKey else { return "—" }
        return KeycodeMap.displayName(for: HotkeyConfig(keyCode: key, modifiers: recordedMods))
    }

    private func startMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            switch event.type {
            case .keyDown:
                if event.keyCode == kVK_Escape {
                    dismiss()
                    return nil
                }
                if KeycodeMap.isRecordableKey(event.keyCode) {
                    recordedKey = UInt32(event.keyCode)
                    recordedMods = KeycodeMap.carbonModifiers(from: event.modifierFlags)
                }
                return nil
            case .flagsChanged:
                recordedMods = KeycodeMap.carbonModifiers(from: event.modifierFlags)
                return nil
            default:
                return event
            }
        }
    }

    private func stopMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func save() {
        guard let key = recordedKey else { return }
        appState.setHotkey(HotkeyConfig(keyCode: key, modifiers: recordedMods))
        dismiss()
    }

    private func dismiss() {
        stopMonitor()
        isPresented = false
    }
}

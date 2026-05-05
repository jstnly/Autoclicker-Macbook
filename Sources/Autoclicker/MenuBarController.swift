import SwiftUI
import AppKit

struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(appState.engine.isRunning ? "Stop" : "Start") {
            appState.engine.toggle()
        }

        Divider()

        Text("Hotkey: \(KeycodeMap.displayName(for: appState.settings.hotkey))")
        Text("Mode: \(appState.settings.mode.displayName)")
        Text("Speed: \(Int(appState.settings.cps)) CPS")
        Text("Clicks: \(appState.engine.clickCount)")

        Divider()

        Picker("Mode", selection: $appState.settings.mode) {
            ForEach(ClickMode.allCases) { Text($0.displayName).tag($0) }
        }
        Picker("Button", selection: $appState.settings.button) {
            ForEach(MouseButton.allCases) { Text($0.displayName).tag($0) }
        }

        Divider()

        Button("Show Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }

        Divider()

        Button("Quit Autoclicker") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

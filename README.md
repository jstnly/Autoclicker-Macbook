# Autoclicker

A native macOS autoclicker for idle clicker games. Runs as a real `.app`,
toggled by a global hotkey. Click at the cursor or at fixed screen locations.

## Features

- Adjustable click speed (1–100 CPS, with finer values via the text field)
- Global toggle hotkey (default `⌃⌥⌘C`) — works even with a fullscreen game in focus
- Two click modes:
  - **Follow Cursor** (default) — clicks at the current mouse position
  - **Fixed Locations** — clicks at one or more saved points each cycle
- Capture cursor position with a 3-second countdown for easy point-saving
- Left or right mouse button
- Optional jitter (randomized interval) for games that detect periodic input
- Optional Down → Up gap for games that ignore zero-duration clicks
- Menu-bar icon for quick start/stop without bringing the window forward
- Settings persist between launches

## Build

You need the Xcode Command Line Tools (Xcode itself is **not** required):

```sh
xcode-select --install
```

Then in the project root:

```sh
./build.sh
```

This produces `Autoclicker.app` at the project root. Open it:

```sh
open Autoclicker.app
```

To install to `/Applications` (recommended — see "Accessibility permission" below):

```sh
./build.sh --install
```

## Accessibility permission

macOS does not allow apps to post synthetic mouse events without explicit
permission. On first launch, the app will prompt for Accessibility access.

1. Click **Open Accessibility Settings** in the app's banner.
2. In **System Settings › Privacy & Security › Accessibility**, enable
   **Autoclicker**.
3. Return to the app — the banner clears within ~2 seconds.

### Permission surviving rebuilds

macOS keys this permission to the app's code-signing identity. Each
ad-hoc rebuild changes the binary hash, so macOS may silently revoke the
permission and you will need to re-toggle the entry in System Settings.

Two ways to avoid this:

**Option A (simple):** Install once to `/Applications` (`./build.sh --install`),
grant Accessibility, and always rebuild into the same path. macOS is more
tolerant when the bundle path is stable.

**Option B (best):** Create a self-signed certificate once and sign with it.
Permission then survives every rebuild.

```text
1. Open Keychain Access.
2. Menu: Keychain Access › Certificate Assistant › Create a Certificate…
3. Name: Autoclicker Self-Signed
   Identity Type: Self Signed Root
   Certificate Type: Code Signing
4. Click Create, then Continue / Done.
```

Then build with that identity:

```sh
./build.sh --identity="Autoclicker Self-Signed"
```

## Using the app

1. Open `Autoclicker.app`.
2. Set **Speed** to your preferred CPS.
3. Pick **Follow Cursor** (default) or **Fixed Locations**.
   - For Fixed Locations, click **Capture Cursor (3s)**, position your cursor
     over the target, and wait. The point appears in the list. Add as many
     points as you need.
4. Press the **toggle hotkey** (default `⌃⌥⌘C`) to start clicking. Press it
   again to stop. You can also use the **Start** button or the menu-bar icon.
5. To change the hotkey, click **Change…** and press your new key combination.

### Game compatibility tips

- If a game seems to ignore your clicks: open **Advanced** and increase the
  **Down → Up gap** to 30–80 ms.
- If a game detects automated clicks: increase **Jitter** to ~10–20 %.
- For games that read mouse position from the operating system rather than
  from the events directly: enable **Restore cursor after each cycle** in
  Fixed-Locations mode so the visible cursor returns to where you left it.

## Project layout

- `Sources/Autoclicker/` — Swift source
  - `AutoclickerApp.swift` — `@main` SwiftUI app + AppDelegate
  - `ContentView.swift` — main settings window
  - `MenuBarController.swift` — menu-bar item
  - `AppState.swift` — central `ObservableObject`
  - `ClickEngine.swift` — click loop (`DispatchSourceTimer` + `CGEvent`)
  - `HotkeyManager.swift` — Carbon `RegisterEventHotKey` wrapper
  - `PermissionsManager.swift` — Accessibility check
  - `KeycodeMap.swift` — virtual keycode ⇄ display name
  - `Settings.swift` / `Models.swift` — persisted state
- `Resources/` — `Info.plist`, `entitlements.plist`
- `build.sh` — builds the `.app` and codesigns
- `Package.swift` — Swift Package Manager manifest

## License

For personal use.

import Foundation
import AppKit
import Carbon.HIToolbox

enum KeycodeMap {
    /// Map of Carbon virtual key codes to short, human-readable display names.
    /// Only includes keys that make sense as a hotkey trigger.
    static let keyName: [UInt32: String] = {
        var m: [UInt32: String] = [:]
        // Letters
        m[UInt32(kVK_ANSI_A)] = "A"; m[UInt32(kVK_ANSI_B)] = "B"; m[UInt32(kVK_ANSI_C)] = "C"
        m[UInt32(kVK_ANSI_D)] = "D"; m[UInt32(kVK_ANSI_E)] = "E"; m[UInt32(kVK_ANSI_F)] = "F"
        m[UInt32(kVK_ANSI_G)] = "G"; m[UInt32(kVK_ANSI_H)] = "H"; m[UInt32(kVK_ANSI_I)] = "I"
        m[UInt32(kVK_ANSI_J)] = "J"; m[UInt32(kVK_ANSI_K)] = "K"; m[UInt32(kVK_ANSI_L)] = "L"
        m[UInt32(kVK_ANSI_M)] = "M"; m[UInt32(kVK_ANSI_N)] = "N"; m[UInt32(kVK_ANSI_O)] = "O"
        m[UInt32(kVK_ANSI_P)] = "P"; m[UInt32(kVK_ANSI_Q)] = "Q"; m[UInt32(kVK_ANSI_R)] = "R"
        m[UInt32(kVK_ANSI_S)] = "S"; m[UInt32(kVK_ANSI_T)] = "T"; m[UInt32(kVK_ANSI_U)] = "U"
        m[UInt32(kVK_ANSI_V)] = "V"; m[UInt32(kVK_ANSI_W)] = "W"; m[UInt32(kVK_ANSI_X)] = "X"
        m[UInt32(kVK_ANSI_Y)] = "Y"; m[UInt32(kVK_ANSI_Z)] = "Z"
        // Digits
        m[UInt32(kVK_ANSI_0)] = "0"; m[UInt32(kVK_ANSI_1)] = "1"; m[UInt32(kVK_ANSI_2)] = "2"
        m[UInt32(kVK_ANSI_3)] = "3"; m[UInt32(kVK_ANSI_4)] = "4"; m[UInt32(kVK_ANSI_5)] = "5"
        m[UInt32(kVK_ANSI_6)] = "6"; m[UInt32(kVK_ANSI_7)] = "7"; m[UInt32(kVK_ANSI_8)] = "8"
        m[UInt32(kVK_ANSI_9)] = "9"
        // Function keys
        m[UInt32(kVK_F1)]  = "F1";  m[UInt32(kVK_F2)]  = "F2";  m[UInt32(kVK_F3)]  = "F3"
        m[UInt32(kVK_F4)]  = "F4";  m[UInt32(kVK_F5)]  = "F5";  m[UInt32(kVK_F6)]  = "F6"
        m[UInt32(kVK_F7)]  = "F7";  m[UInt32(kVK_F8)]  = "F8";  m[UInt32(kVK_F9)]  = "F9"
        m[UInt32(kVK_F10)] = "F10"; m[UInt32(kVK_F11)] = "F11"; m[UInt32(kVK_F12)] = "F12"
        // Other
        m[UInt32(kVK_Space)]      = "Space"
        m[UInt32(kVK_Return)]     = "Return"
        m[UInt32(kVK_Tab)]        = "Tab"
        m[UInt32(kVK_Escape)]     = "Esc"
        m[UInt32(kVK_Delete)]     = "⌫"
        m[UInt32(kVK_LeftArrow)]  = "←"
        m[UInt32(kVK_RightArrow)] = "→"
        m[UInt32(kVK_UpArrow)]    = "↑"
        m[UInt32(kVK_DownArrow)]  = "↓"
        m[UInt32(kVK_ANSI_Comma)]        = ","
        m[UInt32(kVK_ANSI_Period)]       = "."
        m[UInt32(kVK_ANSI_Slash)]        = "/"
        m[UInt32(kVK_ANSI_Semicolon)]    = ";"
        m[UInt32(kVK_ANSI_Quote)]        = "'"
        m[UInt32(kVK_ANSI_LeftBracket)]  = "["
        m[UInt32(kVK_ANSI_RightBracket)] = "]"
        m[UInt32(kVK_ANSI_Backslash)]    = "\\"
        m[UInt32(kVK_ANSI_Minus)]        = "-"
        m[UInt32(kVK_ANSI_Equal)]        = "="
        m[UInt32(kVK_ANSI_Grave)]        = "`"
        return m
    }()

    static func keyDisplayName(for keyCode: UInt32) -> String {
        keyName[keyCode] ?? "Key \(keyCode)"
    }

    static func displayName(for hotkey: HotkeyConfig) -> String {
        var s = ""
        if hotkey.modifiers & HotkeyConfig.controlKey != 0 { s += "⌃" }
        if hotkey.modifiers & HotkeyConfig.optionKey  != 0 { s += "⌥" }
        if hotkey.modifiers & HotkeyConfig.shiftKey   != 0 { s += "⇧" }
        if hotkey.modifiers & HotkeyConfig.cmdKey     != 0 { s += "⌘" }
        s += keyDisplayName(for: hotkey.keyCode)
        return s
    }

    /// Convert Cocoa NSEvent.modifierFlags into the Carbon modifier mask used by RegisterEventHotKey.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= HotkeyConfig.cmdKey }
        if flags.contains(.option)  { m |= HotkeyConfig.optionKey }
        if flags.contains(.control) { m |= HotkeyConfig.controlKey }
        if flags.contains(.shift)   { m |= HotkeyConfig.shiftKey }
        return m
    }

    /// True when this NSEvent represents a "real" key (not a pure modifier press).
    static func isRecordableKey(_ keyCode: UInt16) -> Bool {
        keyName[UInt32(keyCode)] != nil
    }
}

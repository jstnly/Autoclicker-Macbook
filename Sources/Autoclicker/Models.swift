import Foundation
import CoreGraphics

enum ClickMode: String, Codable, CaseIterable, Identifiable {
    case followCursor
    case fixedPoints

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .followCursor: return "Follow Cursor"
        case .fixedPoints:  return "Fixed Locations"
        }
    }
}

enum MouseButton: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:  return "Left"
        case .right: return "Right"
        }
    }
}

struct ClickPoint: Codable, Identifiable, Hashable {
    var id: UUID
    var x: Double
    var y: Double
    var label: String

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    init(id: UUID = UUID(), point: CGPoint, label: String = "") {
        self.id = id
        self.x = point.x
        self.y = point.y
        self.label = label
    }
}

struct HotkeyConfig: Codable, Hashable {
    var keyCode: UInt32     // Carbon virtual key code
    var modifiers: UInt32   // Carbon modifier mask

    // Carbon modifier constants (kept here so non-Carbon-importing files can use them).
    static let cmdKey:     UInt32 = 1 << 8
    static let shiftKey:   UInt32 = 1 << 9
    static let optionKey:  UInt32 = 1 << 11
    static let controlKey: UInt32 = 1 << 12

    // Default: ⌃⌥⌘C — three modifiers + a letter key, unlikely to clash with system shortcuts.
    static let `default` = HotkeyConfig(
        keyCode: 0x08,                                  // kVK_ANSI_C
        modifiers: cmdKey | optionKey | controlKey
    )
}

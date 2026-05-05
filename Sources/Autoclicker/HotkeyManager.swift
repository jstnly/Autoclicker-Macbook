import Foundation
import Carbon.HIToolbox
import AppKit

/// Singleton wrapper around Carbon's `RegisterEventHotKey`.
/// We use Carbon (not `NSEvent.addGlobalMonitor`) because the Carbon API is
/// registered with the WindowServer and continues to fire while a fullscreen
/// game has exclusive focus and across Spaces.
final class HotkeyManager {
    static let shared = HotkeyManager()

    /// Invoked on the main queue whenever the registered hotkey fires.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private let signature: OSType = OSType(0x41434C4B)   // 'ACLK'
    private let hotKeyID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        installHandler()
    }

    /// Register a new hotkey, replacing any prior registration.
    /// Returns `true` if the system accepted the registration.
    @discardableResult
    func register(_ config: HotkeyConfig) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: signature, id: hotKeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(config.keyCode,
                                         config.modifiers,
                                         id,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        guard status == noErr, let validRef = ref else { return false }
        hotKeyRef = validRef
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            { (_, eventRef, _) -> OSStatus in
            guard let eventRef = eventRef else { return noErr }
            var receivedID = EventHotKeyID()
            let status = GetEventParameter(eventRef,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &receivedID)
            if status == noErr,
               receivedID.signature == HotkeyManager.shared.signature,
               receivedID.id == HotkeyManager.shared.hotKeyID {
                DispatchQueue.main.async { HotkeyManager.shared.onTrigger?() }
            }
            return noErr
        }, 1, &spec, nil, &eventHandlerRef)
    }
}

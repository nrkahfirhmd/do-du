//
//  GlobalHotKey.swift
//  Do-Du
//
//  ⌘⇧T from any app starts or stops the timer (macOS). Carbon RegisterEventHotKey
//  works inside the sandbox and needs no Accessibility permission. The Shortcuts
//  actions stay available for people who prefer their own key.
//

#if os(macOS)
import Carbon.HIToolbox
import Foundation
import SwiftData

enum GlobalHotKey {
    static let enabledKey = "globalHotKeyOn"
    private static var hotKey: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    private static var container: ModelContainer?

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    static func register(container: ModelContainer) {
        self.container = container
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // C callback: no captures, hop to the main actor for SwiftData.
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in GlobalHotKey.toggleTimer() }
            return noErr
        }, 1, &spec, nil, &handler)
        apply()
    }

    /// Registers or unregisters ⌘⇧T to match the setting.
    static func apply() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        guard isEnabled else { return }
        let id = EventHotKeyID(signature: OSType(0x444F4455), id: 1)   // 'DODU'
        RegisterEventHotKey(UInt32(kVK_ANSI_T), UInt32(cmdKey | shiftKey), id,
                            GetApplicationEventTarget(), 0, &hotKey)
    }

    private static func toggleTimer() {
        guard let context = container?.mainContext else { return }
        TimerService.toggleQuick(in: context)
    }
}
#endif

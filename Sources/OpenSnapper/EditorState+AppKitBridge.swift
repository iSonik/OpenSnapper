import AppKit
import Carbon
import Foundation

func openSnapperHotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let editor = Unmanaged<EditorState>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        editor.handleGlobalHotkeyEvent(signature: hotKeyID.signature, id: hotKeyID.id)
    }

    return noErr
}

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    var onShouldClose: ((NSWindow) -> Bool)?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onShouldClose?(sender) ?? true
    }
}

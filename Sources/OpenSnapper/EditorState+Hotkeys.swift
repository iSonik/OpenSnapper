import Carbon
import CoreGraphics
import Foundation

extension EditorState {
    enum GlobalHotkeyID {
        static let capture: UInt32 = 1
        static let export: UInt32 = 2
        static let colorPicker: UInt32 = 4
    }

    private struct ParsedGlobalHotkey {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    func installGlobalHotkeyHandlerIfNeeded() {
        guard globalHotkeyHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let target = GetEventDispatcherTarget()
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            target,
            openSnapperHotKeyHandler,
            1,
            &eventType,
            userData,
            &globalHotkeyHandler
        )
    }

    func registerGlobalHotkeys() {
        guard !isLoadingPreferences else { return }

        unregisterGlobalHotkeys()
        guard hasScreenCapturePermissionRightNow() else { return }
        registerGlobalHotkey(definition: captureHotkey, id: GlobalHotkeyID.capture)
        registerGlobalHotkey(definition: exportHotkey, id: GlobalHotkeyID.export)
        registerGlobalHotkey(definition: colorPickerHotkey, id: GlobalHotkeyID.colorPicker)
    }

    func unregisterGlobalHotkeys() {
        for hotkeyRef in globalHotkeyRefs.values {
            UnregisterEventHotKey(hotkeyRef)
        }
        globalHotkeyRefs.removeAll()
    }

    func handleGlobalHotkeyEvent(signature: OSType, id: UInt32) {
        guard signature == globalHotkeySignature else { return }
        guard hasScreenCapturePermissionRightNow() else { return }

        switch id {
        case GlobalHotkeyID.capture:
            captureScreenshot()
        case GlobalHotkeyID.export:
            exportPNG()
        case GlobalHotkeyID.colorPicker:
            pickColorFromScreen()
        default:
            break
        }
    }

    func hasScreenCapturePermissionRightNow() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    private func registerGlobalHotkey(definition: String, id: UInt32) {
        guard let parsed = parseGlobalHotkey(definition) else { return }

        let hotKeyID = EventHotKeyID(signature: globalHotkeySignature, id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            parsed.keyCode,
            parsed.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            globalHotkeyRefs[id] = hotKeyRef
        }
    }

    private func parseGlobalHotkey(_ definition: String) -> ParsedGlobalHotkey? {
        let trimmed = definition
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed
            .split(separator: "+")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let keyPart = parts.last else { return nil }
        guard let keyCode = HotkeyKeyMap.keyCode(for: keyPart) else { return nil }

        var modifiers: UInt32 = 0
        for token in parts.dropLast() {
            switch token {
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "opt", "option", "alt":
                modifiers |= UInt32(optionKey)
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            default:
                return nil
            }
        }

        return ParsedGlobalHotkey(keyCode: keyCode, modifiers: modifiers)
    }
}

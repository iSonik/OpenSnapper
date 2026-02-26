import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var editor: EditorState
    @State private var recordingTarget: HotkeyTarget?
    @State private var hotkeyCaptureMonitor: Any?

    private enum HotkeyTarget: Equatable {
        case capture
        case export
        case colorPicker
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch OpenSnapper at Login", isOn: $editor.launchAtLogin)
            }

            Section("Export") {
                Picker("Default Format", selection: $editor.exportFormat) {
                    ForEach(EditorState.ExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                Picker("Copy Format", selection: $editor.copyImageFormat) {
                    ForEach(EditorState.ExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                TextField("Filename Template", text: $editor.filenameTemplate)
                    .textFieldStyle(.roundedBorder)

                Text("Use {date}, {time}, {date_time}. Default: screenshot_{date}_{time}")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Default Folder")
                        .frame(width: 110, alignment: .leading)

                    Text(editor.defaultSaveFolderPath.isEmpty ? "Ask every time" : editor.defaultSaveFolderPath)
                        .font(.callout)
                        .foregroundStyle(editor.defaultSaveFolderPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Choose...") {
                        chooseFolder()
                    }

                    if editor.hasDefaultSaveFolder {
                        Button("Clear") {
                            editor.clearDefaultSaveFolder()
                        }
                    }
                }

                Toggle("Ask Every Time On Save", isOn: $editor.askForSaveLocationEachTime)
                Toggle("Hide to Menu Bar After Cmd+C Copy", isOn: $editor.closeAppOnCopyShortcut)
            }

            Section("Global Hotkeys") {
                hotkeyRow(title: "Capture", target: .capture)
                hotkeyRow(title: "Export", target: .export)
                hotkeyRow(title: "Color Picker", target: .colorPicker)

                Text("Click Change, then press your shortcut. Use Esc to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Copy/Paste stay app-local with Cmd+C and Cmd+V.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 700)
        .onChange(of: recordingTarget) { target in
            if target == nil {
                removeCaptureMonitor()
            } else {
                installCaptureMonitorIfNeeded()
            }
        }
        .onDisappear {
            removeCaptureMonitor()
        }
    }

    private func hotkeyRow(title: String, target: HotkeyTarget) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 110, alignment: .leading)

            Text(displayHotkey(for: target))
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )

            if recordingTarget == target {
                Text("Press shortcut...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 0)

            Button(recordingTarget == target ? "Cancel" : "Change") {
                recordingTarget = recordingTarget == target ? nil : target
            }

            Button("Clear") {
                setHotkey("", for: target)
                if recordingTarget == target {
                    recordingTarget = nil
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            editor.setDefaultSaveFolder(url: url)
        }
    }

    private func displayHotkey(for target: HotkeyTarget) -> String {
        let value = hotkeyValue(for: target)
        return value.isEmpty ? "Not set" : value
    }

    private func hotkeyValue(for target: HotkeyTarget) -> String {
        switch target {
        case .capture:
            editor.captureHotkey
        case .export:
            editor.exportHotkey
        case .colorPicker:
            editor.colorPickerHotkey
        }
    }

    private func setHotkey(_ value: String, for target: HotkeyTarget) {
        switch target {
        case .capture:
            editor.captureHotkey = value
        case .export:
            editor.exportHotkey = value
        case .colorPicker:
            editor.colorPickerHotkey = value
        }
    }

    private func installCaptureMonitorIfNeeded() {
        guard hotkeyCaptureMonitor == nil else { return }

        hotkeyCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let target = recordingTarget else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                recordingTarget = nil
                return nil
            }

            guard let shortcut = shortcutString(from: event) else {
                NSSound.beep()
                return nil
            }

            setHotkey(shortcut, for: target)
            recordingTarget = nil
            return nil
        }
    }

    private func removeCaptureMonitor() {
        if let hotkeyCaptureMonitor {
            NSEvent.removeMonitor(hotkeyCaptureMonitor)
            self.hotkeyCaptureMonitor = nil
        }
    }

    private func shortcutString(from event: NSEvent) -> String? {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !modifiers.isEmpty else { return nil }
        guard let key = hotkeyToken(for: event.keyCode) else { return nil }

        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("cmd") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.option) { parts.append("opt") }
        if modifiers.contains(.control) { parts.append("ctrl") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    private func hotkeyToken(for keyCode: UInt16) -> String? {
        HotkeyKeyMap.token(for: keyCode)
    }
}

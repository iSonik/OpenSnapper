import SwiftUI

@main
struct OpenSnapperApp: App {
    @StateObject private var editor = EditorState()
    @StateObject private var statusBarController = StatusBarController()

    var body: some Scene {
        WindowGroup("OpenSnapper") {
            ContentView()
                .environmentObject(editor)
                .frame(minWidth: 1100, minHeight: 740)
                .onAppear {
                    statusBarController.installIfNeeded(editor: editor)
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(AppStrings.App.hideToMenuBar) {
                    editor.hideToMenuBar()
                }
                .keyboardShortcut("q", modifiers: .command)

                Button("Close (Hide to Menu Bar)") {
                    editor.hideToMenuBar()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }

            CommandGroup(replacing: .saveItem) {
                Button(AppStrings.Controls.save) {
                    editor.exportPNG()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!editor.hasImage)

                Button(AppStrings.Controls.saveAs) {
                    editor.exportPNG(forcePromptForLocation: true)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!editor.hasImage)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    editor.undoLastChange()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!editor.canUndo)
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Copy") {
                    editor.copySelectionOrImage(triggeredByKeyboardShortcut: true)
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(!editor.hasImage)

                Button("Paste") {
                    editor.pasteFromClipboard()
                }
                .keyboardShortcut("v", modifiers: .command)
            }
        }

        Window("Settings", id: "settings-window") {
            SettingsView()
                .environmentObject(editor)
        }

        Settings {
            SettingsView()
                .environmentObject(editor)
        }
    }
}

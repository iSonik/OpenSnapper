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
                    editor.copySelectionOrImage()
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

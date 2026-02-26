import AppKit
import Foundation

extension EditorState {
    func hideToMenuBar() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
        setStatus(AppStrings.Messages.runningInBackground)
    }

    func openSettingsWindow() {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        let opened = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if !opened {
            _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    func showMainWindow() {
        bringMainWindowToFront()
    }

    func registerMainWindow(_ window: NSWindow) {
        if mainWindow !== window {
            mainWindow = window
            window.isReleasedWhenClosed = false
            let delegate = MainWindowDelegate()
            delegate.onShouldClose = { [weak self] sender in
                sender.orderOut(nil)
                self?.setStatus(AppStrings.Messages.runningInBackground)
                return false
            }
            mainWindowDelegate = delegate
            window.delegate = delegate
        }
    }

    func bringMainWindowToFront() {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)

        if let mainWindow {
            mainWindow.alphaValue = 1
            mainWindow.ignoresMouseEvents = false
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        if let anyWindow = NSApp.windows.first {
            anyWindow.alphaValue = 1
            anyWindow.ignoresMouseEvents = false
            anyWindow.makeKeyAndOrderFront(nil)
        }
    }
}

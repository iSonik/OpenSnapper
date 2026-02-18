import AppKit
import Combine
import CoreGraphics
import Foundation
import SQLite3

@MainActor
final class StatusBarController: NSObject, ObservableObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private weak var editor: EditorState?
    private var cancellables: Set<AnyCancellable> = []
    let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    var cachedScreenCapturePermission: Bool?
    var cachedScreenCapturePermissionAt: Date?

    func installIfNeeded(editor: EditorState) {
        self.editor = editor
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = statusIconImage()
            button.imageScaling = .scaleProportionallyUpOrDown
            button.imagePosition = .imageLeft
            button.toolTip = AppStrings.StatusBar.tooltip
            button.title = ""
        }

        bindRebuild(editor.$recentPickedColors)
        bindRebuild(editor.$recentScreenshots)
        bindRebuild(editor.$isColorPickerActive, updateHoverLabel: true)
        bindRebuild(editor.$liveHoverColorHex, updateHoverLabel: true)
        editor.$hasScreenCaptureAccess
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.invalidateScreenCapturePermissionCache()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.editor?.refreshScreenCaptureAccess()
            }
            .store(in: &cancellables)

        updateButtonHoverLabel()
        rebuildMenu()
    }

    private func bindRebuild<P: Publisher>(_ publisher: P, updateHoverLabel: Bool = false)
    where P.Failure == Never {
        publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if updateHoverLabel {
                    self.updateButtonHoverLabel()
                }
                self.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func makeMenuItem(
        title: String,
        action: Selector,
        isEnabled: Bool = true,
        image: NSImage? = nil,
        representedObject: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = isEnabled
        item.image = image
        item.representedObject = representedObject
        return item
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        addScreenshotSection(to: menu)
        menu.addItem(.separator())
        addColorPickerSection(to: menu)
        menu.addItem(.separator())
        addAppSection(to: menu)
        menu.addItem(.separator())
        if !hasScreenCapturePermission {
            menu.addItem(makeMenuItem(title: AppStrings.StatusBar.enableScreenRecording, action: #selector(openScreenRecordingSettings)))
            menu.addItem(.separator())
        }
        menu.addItem(makeMenuItem(title: AppStrings.StatusBar.quit, action: #selector(quitApp)))
        applyPermissionState(to: menu)
        statusItem?.menu = menu
    }

    private func addScreenshotSection(to menu: NSMenu) {
        let toolsEnabled = hasScreenCapturePermission
        menu.addItem(makeMenuItem(
            title: AppStrings.StatusBar.captureScreenshot,
            action: #selector(captureScreenshot),
            isEnabled: toolsEnabled
        ))

        menu.addItem(makeMenuItem(
            title: AppStrings.StatusBar.captureWholeScreen,
            action: #selector(captureWholeScreen),
            isEnabled: toolsEnabled
        ))

        let screenshots = editor?.recentScreenshots ?? []
        for screenshot in screenshots {
            menu.addItem(makeMenuItem(
                title: screenshot.label,
                action: #selector(copyRecentScreenshot(_:)),
                isEnabled: toolsEnabled,
                image: aspectFitIcon(screenshot.image, dimension: 16),
                representedObject: screenshot.id.uuidString
            ))
        }
    }

    private func addColorPickerSection(to menu: NSMenu) {
        let toolsEnabled = hasScreenCapturePermission
        menu.addItem(makeMenuItem(
            title: AppStrings.StatusBar.colorPick,
            action: #selector(pickScreenColor),
            isEnabled: toolsEnabled
        ))

        if editor?.isColorPickerActive == true {
            let hoverHex = editor?.liveHoverColorHex ?? "--"
            let hover = NSMenuItem(title: AppStrings.StatusBar.hover(hoverHex), action: nil, keyEquivalent: "")
            hover.isEnabled = false
            if let color = color(from: hoverHex) {
                hover.image = swatchImage(for: color)
            }
            menu.addItem(hover)
        }

        let colors = editor?.recentPickedColors ?? []
        for hex in colors {
            let image = color(from: hex).map(swatchImage(for:))
            menu.addItem(makeMenuItem(
                title: hex,
                action: #selector(copyRecentColor(_:)),
                isEnabled: toolsEnabled,
                image: image,
                representedObject: hex
            ))
        }
    }

    private func addAppSection(to menu: NSMenu) {
        menu.addItem(makeMenuItem(
            title: AppStrings.StatusBar.openApp,
            action: #selector(showMainWindow),
            image: statusMenuIconImage()
        ))
        menu.addItem(makeMenuItem(title: AppStrings.StatusBar.settings, action: #selector(openSettings)))
    }

    private func updateButtonHoverLabel() {
        guard let button = statusItem?.button else { return }
        if editor?.isColorPickerActive == true {
            let hoverHex = editor?.liveHoverColorHex ?? "--"
            button.title = " \(hoverHex)"
        } else {
            button.title = ""
        }
    }

    private func withScreenPermission(_ action: (EditorState) -> Void) {
        guard hasScreenCapturePermission, let editor else { return }
        action(editor)
    }

    @objc private func showMainWindow() {
        editor?.showMainWindow()
    }

    @objc private func captureScreenshot() {
        withScreenPermission { $0.captureScreenshot() }
    }

    @objc private func captureWholeScreen() {
        withScreenPermission { $0.captureWholeScreen() }
    }

    @objc private func pickScreenColor() {
        withScreenPermission { $0.pickColorFromScreen() }
    }

    @objc private func copyRecentColor(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String else { return }
        withScreenPermission { $0.copyColorHexToClipboard(hex) }
    }

    @objc private func copyRecentScreenshot(_ sender: NSMenuItem) {
        guard
            let rawID = sender.representedObject as? String,
            let id = UUID(uuidString: rawID)
        else {
            return
        }
        withScreenPermission { $0.copyRecentScreenshotToClipboard(id) }
    }

    @objc private func openSettings() {
        editor?.openSettingsWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        editor?.refreshScreenCaptureAccess()
        invalidateScreenCapturePermissionCache()
        applyPermissionState(to: menu)
    }

    private func applyPermissionState(to menu: NSMenu) {
        let toolsEnabled = hasScreenCapturePermission
        for item in menu.items {
            if isPermissionGatedAction(item.action) {
                item.isEnabled = toolsEnabled
            }
        }
    }

    private func isPermissionGatedAction(_ action: Selector?) -> Bool {
        switch action {
        case #selector(captureScreenshot),
            #selector(captureWholeScreen),
            #selector(pickScreenColor),
            #selector(copyRecentColor(_:)),
            #selector(copyRecentScreenshot(_:)):
            true
        default:
            false
        }
    }

    @objc private func openScreenRecordingSettings() {
        editor?.requestScreenCaptureAndOpenSettingsIfNeeded()
    }
}

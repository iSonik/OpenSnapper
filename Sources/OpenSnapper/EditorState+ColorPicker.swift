import AppKit
import CoreGraphics
import Foundation

extension EditorState {
    private enum ColorPickerDefaults {
        static let permissionError = AppStrings.Messages.colorPickPermissionError
        static let recentColorsLimit = 5
        static let hoverPollIntervalSeconds: TimeInterval = 0.08
        static let samplePixelSize: CGFloat = 1
    }

    func pickColorFromScreen() {
        guard ensureScreenCaptureAccess(errorMessage: ColorPickerDefaults.permissionError) else {
            return
        }

        if activeColorSampler != nil {
            setStatus(AppStrings.Messages.colorPickerAlreadyActive)
            return
        }

        let hiddenWindows = temporarilyHideVisibleWindowsForColorPicker()
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        let sampler = NSColorSampler()
        activeColorSampler = sampler
        isColorPickerActive = true
        startHoverColorTracking()
        sampler.show { [weak self] color in
            Task { @MainActor in
                guard let self else { return }
                defer {
                    self.restoreWindowsAfterColorPicker(hiddenWindows)
                    self.activeColorSampler = nil
                    self.stopHoverColorTracking()
                    self.isColorPickerActive = false
                }

                guard let color else {
                    self.setStatus(AppStrings.Messages.colorPickerCanceled)
                    return
                }

                let sRGBColor = color.usingColorSpace(.sRGB) ?? color
                let hex = Self.hexString(from: sRGBColor)
                self.copyColorHexToClipboard(hex)
            }
        }
    }

    private typealias HiddenColorPickerWindow = (window: NSWindow, alpha: CGFloat, ignoresMouseEvents: Bool)

    private func temporarilyHideVisibleWindowsForColorPicker() -> [HiddenColorPickerWindow] {
        var hiddenWindows: [HiddenColorPickerWindow] = []
        for window in NSApp.windows where window.isVisible {
            hiddenWindows.append((window, window.alphaValue, window.ignoresMouseEvents))
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.orderOut(nil)
        }
        return hiddenWindows
    }

    private func restoreWindowsAfterColorPicker(_ hiddenWindows: [HiddenColorPickerWindow]) {
        for hiddenWindow in hiddenWindows {
            hiddenWindow.window.alphaValue = hiddenWindow.alpha
            hiddenWindow.window.ignoresMouseEvents = hiddenWindow.ignoresMouseEvents
            hiddenWindow.window.orderFrontRegardless()
        }
    }

    func copyColorHexToClipboard(_ hex: String) {
        let normalized = hex.uppercased()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(normalized, forType: .string)
        rememberRecentColor(normalized)
        let message = AppStrings.Messages.copiedColor(normalized)
        showToast(message, isError: false)
        statusMessage = message
    }

    private static func hexString(from color: NSColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        let a = Int(round(alpha * 255))

        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func rememberRecentColor(_ hex: String) {
        var updated = recentPickedColors.filter { $0 != hex }
        updated.insert(hex, at: 0)
        if updated.count > ColorPickerDefaults.recentColorsLimit {
            updated = Array(updated.prefix(ColorPickerDefaults.recentColorsLimit))
        }
        recentPickedColors = updated
    }

    private func startHoverColorTracking() {
        stopHoverColorTracking()
        updateHoverColorFromCursor()
        hoverColorTimer = Timer.scheduledTimer(withTimeInterval: ColorPickerDefaults.hoverPollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateHoverColorFromCursor()
            }
        }
    }

    private func stopHoverColorTracking() {
        hoverColorTimer?.invalidate()
        hoverColorTimer = nil
        liveHoverColorHex = nil
    }

    private func updateHoverColorFromCursor() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else {
            liveHoverColorHex = nil
            return
        }

        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            liveHoverColorHex = nil
            return
        }

        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        let scale = screen.backingScaleFactor
        let localX = (mouseLocation.x - screen.frame.minX) * scale
        let localY = (screen.frame.maxY - mouseLocation.y) * scale
        let sampleRect = CGRect(
            x: localX,
            y: localY,
            width: ColorPickerDefaults.samplePixelSize,
            height: ColorPickerDefaults.samplePixelSize
        )

        guard let image = CGDisplayCreateImage(displayID, rect: sampleRect) else {
            liveHoverColorHex = nil
            return
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let color = bitmap.colorAt(x: 0, y: 0) else {
            liveHoverColorHex = nil
            return
        }

        let sRGBColor = color.usingColorSpace(.sRGB) ?? color
        liveHoverColorHex = Self.hexString(from: sRGBColor)
    }
}

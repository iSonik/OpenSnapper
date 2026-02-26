import AppKit
import CoreGraphics
import Foundation
import SwiftUI

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

    func pickAnnotationColorFromScreenKeepingAppVisible() {
        guard ensureScreenCaptureAccess(errorMessage: ColorPickerDefaults.permissionError) else {
            return
        }

        if activeColorSampler != nil {
            setStatus(AppStrings.Messages.colorPickerAlreadyActive)
            return
        }

        isAnnotationCanvasColorPickerActive = false
        clearAnnotationCanvasHoverColor()

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
                self.annotationStylePreset = .custom
                self.annotationCustomColor = Color(nsColor: sRGBColor)
                self.rememberRecentColor(hex.uppercased())
                let message = "Picked annotation color \(hex)"
                self.showToast(message, isError: false)
                self.statusMessage = message
            }
        }
    }

    func toggleAnnotationCanvasColorPicker() {
        isAnnotationCanvasColorPickerActive.toggle()
        if isAnnotationCanvasColorPickerActive {
            annotationToolbarPopoverTool = nil
            updateAnnotationCanvasHoverColor(at: .zero, in: canvasSize)
            setStatus("Click the image to sample a color")
        } else {
            clearAnnotationCanvasHoverColor()
        }
    }

    @discardableResult
    func sampleAnnotationColorFromCanvas(at point: CGPoint, in canvasSize: CGSize) -> Bool {
        guard canvasPointHitsDisplayedImage(point, in: canvasSize) else {
            setStatus("Click inside the image to sample a color", isError: true)
            return false
        }

        guard let sampled = sampledImageColor(at: point, in: canvasSize) else {
            setStatus("Click inside the image to sample a color", isError: true)
            return false
        }

        let sRGB = sampled.usingColorSpace(.sRGB) ?? sampled
        annotationStylePreset = .custom
        annotationCustomColor = Color(nsColor: sRGB)
        isAnnotationCanvasColorPickerActive = false
        clearAnnotationCanvasHoverColor()

        let hex = Self.hexString(from: sRGB)
        let message = "Picked annotation color \(hex)"
        showToast(message, isError: false)
        statusMessage = message
        return true
    }

    func updateAnnotationCanvasHoverColor(at point: CGPoint, in canvasSize: CGSize) {
        guard isAnnotationCanvasColorPickerActive else {
            clearAnnotationCanvasHoverColor()
            return
        }

        guard canvasPointHitsDisplayedImage(point, in: canvasSize),
              let color = sampledImageColor(at: point, in: canvasSize)
        else {
            annotationCanvasHoverColor = nil
            annotationCanvasHoverHex = nil
            return
        }

        let sRGB = color.usingColorSpace(.sRGB) ?? color
        annotationCanvasHoverColor = Color(nsColor: sRGB)
        annotationCanvasHoverHex = Self.hexString(from: sRGB)
    }

    func clearAnnotationCanvasHoverColor() {
        annotationCanvasHoverColor = nil
        annotationCanvasHoverHex = nil
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

    private func sampledImageColor(at canvasPoint: CGPoint, in canvasSize: CGSize) -> NSColor? {
        guard let image = sourceImage else { return nil }
        let imagePoint = sourceImagePixelPoint(from: canvasPoint, in: canvasSize, image: image)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let x = Int(imagePoint.x.rounded(.down))
        let y = Int(imagePoint.y.rounded(.down))
        guard x >= 0, y >= 0, x < bitmap.pixelsWide, y < bitmap.pixelsHigh else { return nil }
        return bitmap.colorAt(x: x, y: y)
    }

    private func sourceImagePixelPoint(from canvasPoint: CGPoint, in canvasSize: CGSize, image: NSImage) -> CGPoint {
        let availableWidth = max(1, canvasSize.width - (canvasPadding * 2))
        let availableHeight = max(1, canvasSize.height - (canvasPadding * 2))
        let imageWidth = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        let imageAspect = imageWidth / imageHeight
        let containerAspect = availableWidth / availableHeight

        let fitted: CGSize
        if containerAspect > imageAspect {
            fitted = CGSize(width: availableHeight * imageAspect, height: availableHeight)
        } else {
            fitted = CGSize(width: availableWidth, height: availableWidth / imageAspect)
        }

        let baseRect = CGRect(
            x: (canvasSize.width - fitted.width) / 2,
            y: (canvasSize.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )

        let effectiveScale = max(imageScale, 0.0001)
        let transformedCenter = CGPoint(
            x: baseRect.midX + imageOffsetX,
            y: baseRect.midY + imageOffsetY
        )
        let unscaledCanvasPoint = CGPoint(
            x: baseRect.midX + ((canvasPoint.x - transformedCenter.x) / effectiveScale),
            y: baseRect.midY + ((canvasPoint.y - transformedCenter.y) / effectiveScale)
        )

        let normalizedX = (unscaledCanvasPoint.x - baseRect.minX) / max(baseRect.width, 1)
        let normalizedY = (unscaledCanvasPoint.y - baseRect.minY) / max(baseRect.height, 1)

        let clampedX = min(max(normalizedX, 0), 1)
        let clampedY = min(max(normalizedY, 0), 1)

        return CGPoint(
            x: clampedX * CGFloat(max(1, Int(imageWidth) - 1)),
            y: (1 - clampedY) * CGFloat(max(1, Int(imageHeight) - 1))
        )
    }

    func canvasPointHitsDisplayedImage(_ canvasPoint: CGPoint, in canvasSize: CGSize) -> Bool {
        guard let image = sourceImage else { return false }

        let availableWidth = max(1, canvasSize.width - (canvasPadding * 2))
        let availableHeight = max(1, canvasSize.height - (canvasPadding * 2))
        let imageWidth = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        let imageAspect = imageWidth / imageHeight
        let containerAspect = availableWidth / availableHeight

        let fitted: CGSize
        if containerAspect > imageAspect {
            fitted = CGSize(width: availableHeight * imageAspect, height: availableHeight)
        } else {
            fitted = CGSize(width: availableWidth, height: availableWidth / imageAspect)
        }

        let baseRect = CGRect(
            x: (canvasSize.width - fitted.width) / 2,
            y: (canvasSize.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )

        let effectiveScale = max(imageScale, 0.0001)
        let transformedCenter = CGPoint(
            x: baseRect.midX + imageOffsetX,
            y: baseRect.midY + imageOffsetY
        )
        let unscaledCanvasPoint = CGPoint(
            x: baseRect.midX + ((canvasPoint.x - transformedCenter.x) / effectiveScale),
            y: baseRect.midY + ((canvasPoint.y - transformedCenter.y) / effectiveScale)
        )

        return baseRect.contains(unscaledCanvasPoint)
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

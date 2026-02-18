import AppKit
import Foundation

extension StatusBarController {
    private enum StatusIconLayout {
        static let menuBarWidth: CGFloat = 36
        static let menuBarHeight: CGFloat = 18
        static let menuItemDimension: CGFloat = 16
        static let menuBarScale: CGFloat = 0.8
    }

    func statusIconImage() -> NSImage {
        guard let source = sourceStatusIcon() else {
            return NSImage(size: NSSize(width: StatusIconLayout.menuBarWidth, height: StatusIconLayout.menuBarHeight))
        }
        let icon = aspectFillIcon(
            source.image,
            targetSize: NSSize(width: StatusIconLayout.menuBarWidth, height: StatusIconLayout.menuBarHeight)
        )
        icon.isTemplate = source.isTemplate
        return icon
    }

    func statusMenuIconImage() -> NSImage? {
        guard let source = sourceStatusIcon() else { return nil }
        let icon = aspectFitIcon(source.image, dimension: StatusIconLayout.menuItemDimension)
        icon.isTemplate = source.isTemplate
        return icon
    }

    func aspectFitIcon(_ image: NSImage, dimension: CGFloat) -> NSImage {
        let targetSize = NSSize(width: dimension, height: dimension)
        let output = NSImage(size: targetSize)
        output.lockFocus()
        defer { output.unlockFocus() }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return output
        }

        let scale = min(dimension / sourceSize.width, dimension / sourceSize.height)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawRect = NSRect(
            x: (dimension - drawSize.width) / 2,
            y: (dimension - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        return output
    }

    func color(from hex: String) -> NSColor? {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard value.hasPrefix("#") else { return nil }
        let raw = String(value.dropFirst())
        let scanner = Scanner(string: raw)
        var number: UInt64 = 0
        guard scanner.scanHexInt64(&number) else { return nil }

        switch raw.count {
        case 6:
            let r = CGFloat((number & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((number & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(number & 0x0000FF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
        case 8:
            let r = CGFloat((number & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((number & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((number & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(number & 0x000000FF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    func swatchImage(for color: NSColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        color.setFill()
        path.fill()
        NSColor.black.withAlphaComponent(0.25).setStroke()
        path.lineWidth = 1
        path.stroke()
        return image
    }

    private func sourceStatusIcon() -> (image: NSImage, isTemplate: Bool)? {
        if let bundledIconURL = Bundle.main.url(forResource: "snappingturtleicon", withExtension: "png"),
           let image = NSImage(contentsOf: bundledIconURL)
        {
            return (image, false)
        }

        if let image = NSImage(named: NSImage.Name("AppIcon")) {
            return (image, false)
        }

        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL)
        {
            return (image, false)
        }

        if let image = NSImage(systemSymbolName: "tortoise.fill", accessibilityDescription: AppStrings.App.name) {
            return (image, true)
        }

        return nil
    }

    private func aspectFitIcon(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let output = NSImage(size: targetSize)
        output.lockFocus()
        defer { output.unlockFocus() }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return output
        }

        let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawRect = NSRect(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        return output
    }

    private func aspectFillIcon(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let output = NSImage(size: targetSize)
        output.lockFocus()
        defer { output.unlockFocus() }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return output
        }

        let scale = max(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let scaledWidth = sourceSize.width * scale * StatusIconLayout.menuBarScale
        let scaledHeight = sourceSize.height * scale * StatusIconLayout.menuBarScale
        let drawSize = NSSize(width: scaledWidth, height: scaledHeight)
        let drawRect = NSRect(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        return output
    }
}

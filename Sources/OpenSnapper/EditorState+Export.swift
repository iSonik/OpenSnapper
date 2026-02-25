import AppKit
import Foundation
import SwiftUI

extension EditorState {
    private func resolvedFilenameBase() -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current

        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datePart = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "HH-mm-ss"
        let timePart = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateTimePart = dateFormatter.string(from: now)

        let raw = filenameTemplate.isEmpty ? AppStrings.Messages.defaultFilenameTemplate : filenameTemplate
        let withTokens = raw
            .replacingOccurrences(of: "{date_time}", with: dateTimePart)
            .replacingOccurrences(of: "{date}", with: datePart)
            .replacingOccurrences(of: "{time}", with: timePart)

        let sanitized = withTokens
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "\(AppStrings.Messages.unresolvedFilenameFallback)\(dateTimePart)" : sanitized
    }

    private func uniqueSaveURL(in folderURL: URL, baseName: String, fileExtension: String) -> URL {
        let fm = FileManager.default
        let sanitizedBase = baseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppStrings.Messages.defaultFilenameFallbackBase : baseName
        var candidate = folderURL.appendingPathComponent(sanitizedBase).appendingPathExtension(fileExtension)
        var suffix = 2

        while fm.fileExists(atPath: candidate.path) {
            candidate = folderURL
                .appendingPathComponent("\(sanitizedBase)-\(suffix)")
                .appendingPathExtension(fileExtension)
            suffix += 1
        }

        return candidate
    }

    func exportPNG(forcePromptForLocation: Bool = false) {
        guard let rendered = renderedImage() else {
            setStatus(AppStrings.Messages.nothingToSave, isError: true)
            return
        }

        let format = exportFormat
        guard
            let tiff = rendered.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            setStatus(AppStrings.Messages.failedToRenderImage, isError: true)
            return
        }

        let data: Data?
        switch format {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .jpg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
        }

        guard let data else {
            setStatus(AppStrings.Messages.failedToEncode(format.title), isError: true)
            return
        }

        let outputURL: URL
        let shouldPromptForLocation = forcePromptForLocation || askForSaveLocationEachTime
        if !shouldPromptForLocation {
            guard let folderURL = defaultSaveFolderURL else {
                setStatus(AppStrings.Messages.setDefaultFolderOrAsk, isError: true)
                return
            }
            outputURL = uniqueSaveURL(in: folderURL, baseName: resolvedFilenameBase(), fileExtension: format.fileExtension)
        } else {
            let panel = NSSavePanel()
            switch format {
            case .png:
                panel.allowedContentTypes = [.png]
            case .jpg:
                panel.allowedContentTypes = [.jpeg]
            }
            panel.nameFieldStringValue = "\(resolvedFilenameBase()).\(format.fileExtension)"
            if let directoryURL = defaultSaveFolderURL {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    panel.directoryURL = directoryURL
                }
            }

            guard panel.runModal() == .OK, var selectedURL = panel.url else {
                setStatus(AppStrings.Messages.saveCanceled)
                return
            }
            if selectedURL.pathExtension.isEmpty {
                selectedURL.appendPathExtension(format.fileExtension)
            }
            outputURL = selectedURL
        }

        do {
            try data.write(to: outputURL)
            let message = AppStrings.Messages.saved(outputURL.lastPathComponent)
            setStatus(message)
            showToast(message, isError: false)
        } catch {
            setStatus(AppStrings.Messages.saveFailed(error.localizedDescription), isError: true)
        }
    }

    @discardableResult
    func copyEditedImageToClipboard() -> Bool {
        guard let rendered = renderedImage() else {
            setStatus(AppStrings.Messages.nothingToCopy, isError: true)
            return false
        }

        NSPasteboard.general.clearContents()
        let wrote = NSPasteboard.general.writeObjects([rendered])
        if wrote {
            copyFeedbackID = UUID()
        }
        setStatus(wrote ? AppStrings.Messages.copiedImageToClipboard : AppStrings.Messages.copyFailed, isError: !wrote)
        return wrote
    }

    func copySelectionOrImage(triggeredByKeyboardShortcut: Bool = false) {
        let handledByResponder = NSApp.sendAction(Selector(("copy:")), to: nil, from: nil)
        if handledByResponder {
            return
        }

        let didCopy = copyEditedImageToClipboard()
        if didCopy, triggeredByKeyboardShortcut, closeAppOnCopyShortcut {
            hideToMenuBar()
        }
    }

    func copyRecentScreenshotToClipboard(_ id: UUID) {
        guard let entry = recentScreenshots.first(where: { $0.id == id }) else {
            setStatus(AppStrings.Messages.screenshotNotFound, isError: true)
            return
        }

        NSPasteboard.general.clearContents()
        let wrote = NSPasteboard.general.writeObjects([entry.image])
        setStatus(wrote ? AppStrings.Messages.copiedScreenshotToClipboard : AppStrings.Messages.copyFailed, isError: !wrote)
        if wrote {
            showToast(AppStrings.Messages.copiedScreenshotToast, isError: false)
        }
    }

    private func renderedImage() -> NSImage? {
        guard let image = sourceImage else {
            return nil
        }

        let renderWidth: CGFloat = canvasSize.width > 1 ? canvasSize.width : 1600
        let renderAspect: CGFloat
        if canvasSize.width > 1 && canvasSize.height > 1 {
            renderAspect = max(canvasSize.width / canvasSize.height, 0.1)
        } else {
            renderAspect = max(aspectRatio, 0.1)
        }

        let view = ExportCanvasView(image: image, editor: self, forExport: true)
            .frame(width: renderWidth, height: renderWidth / renderAspect)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.nsImage
    }
}

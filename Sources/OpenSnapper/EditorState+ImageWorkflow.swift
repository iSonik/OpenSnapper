import AppKit
import Foundation
import UniformTypeIdentifiers

extension EditorState {
    func applySourceImage(
        _ image: NSImage,
        successMessage: String? = nil,
        centeringEligible: Bool = false,
        subjectCenter: CGPoint? = nil,
        resetLayout: Bool = false
    ) {
        recordUndoCheckpoint()
        if resetLayout {
            imageScale = LayoutDefaults.imageScale
            imageOffsetX = LayoutDefaults.imageOffsetX
            imageOffsetY = LayoutDefaults.imageOffsetY
            canvasPadding = LayoutDefaults.canvasPadding
            outerCornerRadius = LayoutDefaults.outerCornerRadius
            imageCornerRadius = LayoutDefaults.imageCornerRadius
            shadowRadius = LayoutDefaults.shadowRadius
            shadowOpacity = LayoutDefaults.shadowOpacity
        }
        sourceImage = image
        centeringEnabled = centeringEligible
        if centeringEligible, let subjectCenter {
            detectedSubjectCenterX = subjectCenter.x
            detectedSubjectCenterY = subjectCenter.y
            centeringSource = .foregroundMask
        } else {
            detectedSubjectCenterX = nil
            detectedSubjectCenterY = nil
            centeringSource = nil
        }
        if let successMessage {
            setStatus(successMessage)
        }
        if centeringEligible, subjectCenter != nil {
            updateCenteringIndicator()
        } else {
            analyzeSubjectCentering()
        }
    }

    func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .heic]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }

    func pasteFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
            setStatus(AppStrings.Messages.clipboardHasNoImage, isError: true)
            return
        }
        applySourceImage(image, successMessage: AppStrings.Messages.loadedFromClipboard, centeringEligible: false)
    }

    func loadImage(
        from url: URL,
        successMessage: String? = nil,
        storeAsRecentScreenshot: Bool = false,
        resetLayout: Bool = false
    ) {
        guard let image = NSImage(contentsOf: url) else {
            setStatus(AppStrings.Messages.failedToLoadImage, isError: true)
            return
        }
        if storeAsRecentScreenshot {
            rememberRecentScreenshot(image)
        }
        applySourceImage(
            image,
            successMessage: successMessage ?? AppStrings.Messages.loadedImage(url.lastPathComponent),
            centeringEligible: false,
            resetLayout: resetLayout
        )
    }

    func isolateSubjectWithAI() {
        guard !isRemovingBackground else {
            return
        }

        guard #available(macOS 14.0, *) else {
            setStatus(AppStrings.Messages.removeBGRequiresMacOS14, isError: true)
            return
        }

        guard let image = sourceImage else {
            setStatus(AppStrings.Messages.noImageSelected, isError: true)
            return
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            setStatus(AppStrings.Messages.failedToReadImage, isError: true)
            return
        }

        isRemovingBackground = true
        backgroundRemovalMode = .isolateSubjectAI
        setStatus(AppStrings.Messages.isolatingSubject)

        Task.detached(priority: .userInitiated) { [cgImage] in
            let result = Result { try Self.cutoutForeground(from: cgImage) }
            await MainActor.run {
                switch result {
                case .success(let output):
                    let image = NSImage(
                        cgImage: output.image,
                        size: NSSize(width: output.image.width, height: output.image.height)
                    )
                    self.applySourceImage(
                        image,
                        successMessage: AppStrings.Messages.subjectIsolated,
                        centeringEligible: true,
                        subjectCenter: output.subjectCenter
                    )
                case .failure(let error):
                    if let readableError = error as? LocalizedError, let description = readableError.errorDescription {
                        self.setStatus(AppStrings.Messages.isolateFailed(description), isError: true)
                    } else {
                        self.setStatus(AppStrings.Messages.isolateFailed(error.localizedDescription), isError: true)
                    }
                }

                self.isRemovingBackground = false
                self.backgroundRemovalMode = nil
            }
        }
    }

    func removeSolidBackground() {
        guard !isRemovingBackground else {
            return
        }

        guard let image = sourceImage else {
            setStatus(AppStrings.Messages.noImageSelected, isError: true)
            return
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            setStatus(AppStrings.Messages.failedToReadImage, isError: true)
            return
        }

        isRemovingBackground = true
        backgroundRemovalMode = .solidColor
        setStatus(AppStrings.Messages.removingSolidBackground)

        Task.detached(priority: .userInitiated) { [cgImage] in
            let result = Result {
                try Self.removeSolidBackgroundFromEdges(from: cgImage, tolerance: 0.20, softness: 0.10)
            }
            await MainActor.run {
                switch result {
                case .success(let outputCGImage):
                    let image = NSImage(
                        cgImage: outputCGImage,
                        size: NSSize(width: outputCGImage.width, height: outputCGImage.height)
                    )
                    self.applySourceImage(
                        image,
                        successMessage: AppStrings.Messages.solidBackgroundRemoved,
                        centeringEligible: false
                    )
                case .failure(let error):
                    self.setStatus(AppStrings.Messages.solidBackgroundFailed(error.localizedDescription), isError: true)
                }

                self.isRemovingBackground = false
                self.backgroundRemovalMode = nil
            }
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let typeIdentifier = UTType.fileURL.identifier

        for provider in providers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    return
                }

                Task { @MainActor [weak self] in
                    self?.loadImage(from: url)
                }
            }
            return true
        }

        return false
    }
}

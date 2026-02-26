import AppKit
import CoreGraphics
import Foundation

extension EditorState {
    private enum LayoutCenteringDefaults {
        static let aspectSelectionTolerance: CGFloat = 0.0005
        static let canvasResizeTolerance: CGFloat = 0.5
        static let centeredSubjectCoordinate: CGFloat = 0.5
        static let minRenderAspect: CGFloat = 0.1
        static let fallbackCanvasWidth: CGFloat = 1600
        static let minImageDimension: CGFloat = 1
        static let centeringThresholdMinPixels: CGFloat = 8
        static let centeringThresholdRatio: CGFloat = 0.03
    }

    enum LayoutDefaults {
        static let canvasPadding: CGFloat = 86
        static let outerCornerRadius: CGFloat = 30
        static let imageCornerRadius: CGFloat = 20
        static let shadowRadius: CGFloat = 24
        static let shadowOpacity: Double = 0.26
        static let imageScale: CGFloat = 1.0
        static let imageOffsetX: CGFloat = 0
        static let imageOffsetY: CGFloat = 0

        enum CustomPreset {
            static let aspectRatio: CGFloat = 4.0 / 5.0
            static let canvasPadding: CGFloat = 70
            static let outerCornerRadius: CGFloat = 38
            static let imageCornerRadius: CGFloat = 26
            static let shadowRadius: CGFloat = 20
            static let shadowOpacity: Double = 0.20
        }
    }

    enum LayoutRanges {
        static let zoom: ClosedRange<CGFloat> = 0.5...2.0
        static let offset: ClosedRange<CGFloat> = -320...320
        static let padding: ClosedRange<CGFloat> = 0...180
        static let outerCornerRadius: ClosedRange<CGFloat> = 0...72
        static let imageCornerRadius: ClosedRange<CGFloat> = 0...48
        static let shadowRadius: ClosedRange<CGFloat> = 0...48
        static let shadowOpacity: ClosedRange<Double> = 0...0.6
    }

    static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(range.upperBound, max(range.lowerBound, value))
    }

    static let standardAspectPresets: [AspectPreset] = [
        AspectPreset(id: "16:10", title: "16:10", ratio: 16.0 / 10.0),
        AspectPreset(id: "16:9", title: "16:9", ratio: 16.0 / 9.0),
        AspectPreset(id: "21:9", title: "21:9", ratio: 21.0 / 9.0),
        AspectPreset(id: "3:2", title: "3:2", ratio: 3.0 / 2.0),
        AspectPreset(id: "4:3", title: "4:3", ratio: 4.0 / 3.0),
        AspectPreset(id: "5:4", title: "5:4", ratio: 5.0 / 4.0),
        AspectPreset(id: "1:1", title: "1:1", ratio: 1.0),
        AspectPreset(id: "4:5", title: "4:5", ratio: 4.0 / 5.0),
        AspectPreset(id: "3:4", title: "3:4", ratio: 3.0 / 4.0),
        AspectPreset(id: "2:3", title: "2:3", ratio: 2.0 / 3.0),
        AspectPreset(id: "9:16", title: "9:16", ratio: 9.0 / 16.0),
    ]

    var selectedStandardAspectRatioID: String? {
        guard !isAppIconLayout, !isCustomLayoutMode else { return nil }
        return Self.standardAspectPresets.first {
            abs($0.ratio - aspectRatio) < LayoutCenteringDefaults.aspectSelectionTolerance
        }?.id
    }

    var isCustomRoundedLayoutPreset: Bool {
        guard !isAppIconLayout else { return false }
        return
            abs(aspectRatio - LayoutDefaults.CustomPreset.aspectRatio) < LayoutCenteringDefaults.aspectSelectionTolerance &&
            abs(canvasPadding - LayoutDefaults.CustomPreset.canvasPadding) < 0.5 &&
            abs(outerCornerRadius - LayoutDefaults.CustomPreset.outerCornerRadius) < 0.5 &&
            abs(imageCornerRadius - LayoutDefaults.CustomPreset.imageCornerRadius) < 0.5
    }

    func setAspectRatio(_ ratio: CGFloat) {
        guard !isOriginalStyleLayoutLocked else { return }
        recordUndoCheckpoint()
        isAppIconLayout = false
        isCustomLayoutMode = false
        aspectRatio = ratio
    }

    func applyAppIconLayoutPreset() {
        guard !isOriginalStyleLayoutLocked else { return }
        recordUndoCheckpoint()
        isAppIconLayout = true
        isCustomLayoutMode = false
        aspectRatio = 1.0
        canvasPadding = LayoutDefaults.canvasPadding
        outerCornerRadius = LayoutDefaults.outerCornerRadius
        imageCornerRadius = LayoutDefaults.imageCornerRadius
        shadowRadius = LayoutDefaults.shadowRadius
        shadowOpacity = LayoutDefaults.shadowOpacity
        imageScale = LayoutDefaults.imageScale
        imageOffsetX = LayoutDefaults.imageOffsetX
        imageOffsetY = LayoutDefaults.imageOffsetY
        setStatus(AppStrings.Messages.appliedAppIconLayout)
    }

    func applyCustomRoundedLayoutPreset() {
        guard !isOriginalStyleLayoutLocked else { return }
        recordUndoCheckpoint()
        isAppIconLayout = false
        isCustomLayoutMode = true
        aspectRatio = LayoutDefaults.CustomPreset.aspectRatio
        canvasPadding = LayoutDefaults.CustomPreset.canvasPadding
        outerCornerRadius = LayoutDefaults.CustomPreset.outerCornerRadius
        imageCornerRadius = LayoutDefaults.CustomPreset.imageCornerRadius
        shadowRadius = LayoutDefaults.CustomPreset.shadowRadius
        shadowOpacity = LayoutDefaults.CustomPreset.shadowOpacity
        setStatus(AppStrings.Messages.appliedCustomLayout)
    }

    func applyCustomLayout(
        aspectRatio: CGFloat,
        outerCornerRadius: CGFloat
    ) {
        guard !isOriginalStyleLayoutLocked else { return }
        recordUndoCheckpoint()
        isAppIconLayout = false
        isCustomLayoutMode = true
        self.aspectRatio = max(aspectRatio, LayoutCenteringDefaults.minRenderAspect)
        self.outerCornerRadius = Self.clamp(outerCornerRadius, to: LayoutRanges.outerCornerRadius)
        setStatus(AppStrings.Messages.appliedCustomLayout)
    }

    func resetLayoutAdjustments() {
        recordUndoCheckpoint()
        imageScale = LayoutDefaults.imageScale
        imageOffsetX = LayoutDefaults.imageOffsetX
        imageOffsetY = LayoutDefaults.imageOffsetY
        isCustomLayoutMode = false
        canvasPadding = LayoutDefaults.canvasPadding
        outerCornerRadius = LayoutDefaults.outerCornerRadius
        imageCornerRadius = LayoutDefaults.imageCornerRadius
        shadowRadius = LayoutDefaults.shadowRadius
        shadowOpacity = LayoutDefaults.shadowOpacity
        setStatus(AppStrings.Messages.resetLayout)
    }

    func setAppIconShape(_ shape: AppIconShape) {
        guard !isOriginalStyleLayoutLocked else { return }
        guard appIconShape != shape else { return }
        recordUndoCheckpoint()
        appIconShape = shape
        isAppIconLayout = true
        isCustomLayoutMode = false
        setStatus(AppStrings.Messages.appIconShape(shape.title))
    }

    func setCanvasSize(_ size: CGSize) {
        guard
            abs(canvasSize.width - size.width) > LayoutCenteringDefaults.canvasResizeTolerance ||
            abs(canvasSize.height - size.height) > LayoutCenteringDefaults.canvasResizeTolerance
        else {
            return
        }
        canvasSize = size
        updateCenteringIndicator()
    }

    func autoCenterVertically() {
        guard centeringEnabled else {
            setStatus(AppStrings.Messages.autoCenterAfterRemoveBackground)
            return
        }

        guard
            let image = sourceImage,
            let subjectCenterX = detectedSubjectCenterX,
            let subjectCenterY = detectedSubjectCenterY
        else {
            return
        }

        recordUndoCheckpoint()
        let displayedSize = estimateDisplayedImageSize(for: image)
        let displacementX = ((LayoutCenteringDefaults.centeredSubjectCoordinate - subjectCenterX) * displayedSize.width * imageScale) + imageOffsetX
        let displacementY = ((LayoutCenteringDefaults.centeredSubjectCoordinate - subjectCenterY) * displayedSize.height * imageScale) + imageOffsetY
        imageOffsetX -= displacementX
        imageOffsetY -= displacementY
    }

    func analyzeSubjectCentering() {
        detectedSubjectCenterX = nil
        detectedSubjectCenterY = nil
        centeringSource = nil
        centeringMessage = AppStrings.Messages.analyzingCentering
        isSubjectCentered = false

        guard centeringEnabled else {
            centeringMessage = AppStrings.Messages.centeringAfterRemoveBackground
            return
        }

        guard
            let image = sourceImage,
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            centeringMessage = AppStrings.Messages.loadImageToAnalyzeCentering
            updateCenteringIndicator()
            return
        }

        Task.detached(priority: .utility) { [cgImage] in
            let center: CGPoint? = if #available(macOS 14.0, *) {
                try? Self.detectSubjectCenter(from: cgImage)
            } else {
                nil
            }
            await MainActor.run {
                self.detectedSubjectCenterX = center?.x
                self.detectedSubjectCenterY = center?.y
                self.centeringSource = center == nil ? nil : .foregroundMask
                self.updateCenteringIndicator()
            }
        }
    }

    func updateCenteringIndicator() {
        guard let image = sourceImage else {
            centeringMessage = AppStrings.Messages.loadImageToAnalyzeCentering
            isSubjectCentered = false
            return
        }

        guard centeringEnabled else {
            centeringMessage = AppStrings.Messages.centeringAfterRemoveBackground
            isSubjectCentered = false
            return
        }

        guard
            let subjectCenterX = detectedSubjectCenterX,
            let subjectCenterY = detectedSubjectCenterY
        else {
            centeringMessage = AppStrings.Messages.visionCouldNotDetectCenter
            isSubjectCentered = false
            return
        }

        let displayedSize = estimateDisplayedImageSize(for: image)
        let displacementX = ((LayoutCenteringDefaults.centeredSubjectCoordinate - subjectCenterX) * displayedSize.width * imageScale) + imageOffsetX
        let displacementY = ((LayoutCenteringDefaults.centeredSubjectCoordinate - subjectCenterY) * displayedSize.height * imageScale) + imageOffsetY
        let threshold = max(
            LayoutCenteringDefaults.centeringThresholdMinPixels,
            min(displayedSize.width, displayedSize.height) * LayoutCenteringDefaults.centeringThresholdRatio
        )

        if abs(displacementX) <= threshold && abs(displacementY) <= threshold {
            centeringMessage = AppStrings.Messages.contentCentered
            isSubjectCentered = true
            return
        }

        isSubjectCentered = false
        let horizontalMessage: String
        if abs(displacementX) <= threshold {
            horizontalMessage = ""
        } else if displacementX > 0 {
            horizontalMessage = AppStrings.Messages.directionPixels(AppStrings.Messages.leftPx, Int(displacementX.rounded()))
        } else {
            horizontalMessage = AppStrings.Messages.directionPixels(AppStrings.Messages.rightPx, Int((-displacementX).rounded()))
        }

        let verticalMessage: String
        if abs(displacementY) <= threshold {
            verticalMessage = ""
        } else if displacementY > 0 {
            verticalMessage = AppStrings.Messages.directionPixels(AppStrings.Messages.upPx, Int(displacementY.rounded()))
        } else {
            verticalMessage = AppStrings.Messages.directionPixels(AppStrings.Messages.downPx, Int((-displacementY).rounded()))
        }

        if horizontalMessage.isEmpty {
            centeringMessage = AppStrings.Messages.move(verticalMessage)
        } else if verticalMessage.isEmpty {
            centeringMessage = AppStrings.Messages.move(horizontalMessage)
        } else {
            centeringMessage = AppStrings.Messages.moveBoth(horizontal: horizontalMessage, vertical: verticalMessage)
        }
    }

    func applyOriginalLayoutLock() {
        if isAppIconLayout { isAppIconLayout = false }
    }

    private func estimateDisplayedImageSize(for image: NSImage) -> CGSize {
        let imageHeight = max(image.size.height, LayoutCenteringDefaults.minImageDimension)
        let imageWidth = max(image.size.width, LayoutCenteringDefaults.minImageDimension)
        let imageAspect = imageWidth / imageHeight

        let renderWidth: CGFloat =
            canvasSize.width > LayoutCenteringDefaults.minImageDimension
            ? canvasSize.width
            : LayoutCenteringDefaults.fallbackCanvasWidth
        let renderAspect: CGFloat
        if
            canvasSize.width > LayoutCenteringDefaults.minImageDimension &&
            canvasSize.height > LayoutCenteringDefaults.minImageDimension
        {
            renderAspect = max(canvasSize.width / canvasSize.height, LayoutCenteringDefaults.minRenderAspect)
        } else {
            renderAspect = max(aspectRatio, LayoutCenteringDefaults.minRenderAspect)
        }

        let renderHeight = renderWidth / renderAspect
        let horizontalPadding = canvasPadding * 2
        let verticalPadding = canvasPadding * 2
        let contentWidth = max(LayoutCenteringDefaults.minImageDimension, renderWidth - horizontalPadding)
        let contentHeight = max(LayoutCenteringDefaults.minImageDimension, renderHeight - verticalPadding)
        let displayedHeight = min(contentHeight, contentWidth / imageAspect)
        let displayedWidth = min(contentWidth, contentHeight * imageAspect)
        return CGSize(width: displayedWidth, height: displayedHeight)
    }
}

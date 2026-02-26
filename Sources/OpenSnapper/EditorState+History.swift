import AppKit
import Foundation

extension EditorState {
    func recordUndoCheckpoint() {
        guard !isApplyingSnapshot else { return }
        undoStack.append(makeSnapshot())
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
    }

    func undoLastChange() {
        guard let snapshot = undoStack.popLast() else {
            setStatus(AppStrings.Messages.nothingToUndo)
            return
        }
        applySnapshot(snapshot)
        setStatus(AppStrings.Messages.undidLastChange)
    }

    private func makeSnapshot() -> Snapshot {
        Snapshot(
            sourceImage: sourceImage,
            centeringEnabled: centeringEnabled,
            detectedSubjectCenterX: detectedSubjectCenterX,
            detectedSubjectCenterY: detectedSubjectCenterY,
            centeringSource: centeringSource,
            isAppIconLayout: isAppIconLayout,
            isCustomLayoutMode: isCustomLayoutMode,
            appIconShape: appIconShape,
            backgroundStyle: backgroundStyle,
            solidColor: solidColor,
            canvasPadding: canvasPadding,
            outerCornerRadius: outerCornerRadius,
            imageCornerRadius: imageCornerRadius,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity,
            imageScale: imageScale,
            imageOffsetX: imageOffsetX,
            imageOffsetY: imageOffsetY,
            aspectRatio: aspectRatio,
            annotationStrokeWidth: annotationStrokeWidth,
            annotationBoxFillColor: annotationBoxFillColor,
            annotationBoxFillOpacity: annotationBoxFillOpacity,
            annotationBoxCornerRadius: annotationBoxCornerRadius,
            annotationDrawAutoSmooth: annotationDrawAutoSmooth,
            annotationTextDefaultFontColor: annotationTextDefaultFontColor,
            annotationTextDefaultBackgroundColor: annotationTextDefaultBackgroundColor,
            annotationTextDefaultFontSize: annotationTextDefaultFontSize,
            annotationTextDefaultAlignment: annotationTextDefaultAlignment,
            annotationTextFontColorOverrides: annotationTextFontColorOverrides,
            annotationTextBackgroundColorOverrides: annotationTextBackgroundColorOverrides,
            annotationTextFontSizeOverrides: annotationTextFontSizeOverrides,
            annotationTextAlignmentOverrides: annotationTextAlignmentOverrides,
            annotationColorOverrides: annotationColorOverrides,
            annotationStrokeWidthOverrides: annotationStrokeWidthOverrides,
            annotationBoxFillColorOverrides: annotationBoxFillColorOverrides,
            annotationBoxFillOpacityOverrides: annotationBoxFillOpacityOverrides,
            annotationBoxCornerRadiusOverrides: annotationBoxCornerRadiusOverrides,
            annotationDrawAutoSmoothOverrides: annotationDrawAutoSmoothOverrides,
            annotations: annotations,
            redactionRegions: redactionRegions
        )
    }

    private func applySnapshot(_ snapshot: Snapshot) {
        isApplyingSnapshot = true
        defer { isApplyingSnapshot = false }

        sourceImage = snapshot.sourceImage
        centeringEnabled = snapshot.centeringEnabled
        detectedSubjectCenterX = snapshot.detectedSubjectCenterX
        detectedSubjectCenterY = snapshot.detectedSubjectCenterY
        centeringSource = snapshot.centeringSource
        isAppIconLayout = snapshot.isAppIconLayout
        isCustomLayoutMode = snapshot.isCustomLayoutMode
        appIconShape = snapshot.appIconShape
        backgroundStyle = snapshot.backgroundStyle
        solidColor = snapshot.solidColor
        canvasPadding = snapshot.canvasPadding
        outerCornerRadius = snapshot.outerCornerRadius
        imageCornerRadius = snapshot.imageCornerRadius
        shadowRadius = snapshot.shadowRadius
        shadowOpacity = snapshot.shadowOpacity
        imageScale = snapshot.imageScale
        imageOffsetX = snapshot.imageOffsetX
        imageOffsetY = snapshot.imageOffsetY
        aspectRatio = snapshot.aspectRatio
        annotationStrokeWidth = snapshot.annotationStrokeWidth
        annotationBoxFillColor = snapshot.annotationBoxFillColor
        annotationBoxFillOpacity = snapshot.annotationBoxFillOpacity
        annotationBoxCornerRadius = snapshot.annotationBoxCornerRadius
        annotationDrawAutoSmooth = snapshot.annotationDrawAutoSmooth
        annotationTextDefaultFontColor = snapshot.annotationTextDefaultFontColor
        annotationTextDefaultBackgroundColor = snapshot.annotationTextDefaultBackgroundColor
        annotationTextDefaultFontSize = snapshot.annotationTextDefaultFontSize
        annotationTextDefaultAlignment = snapshot.annotationTextDefaultAlignment
        annotationTextFontColorOverrides = snapshot.annotationTextFontColorOverrides
        annotationTextBackgroundColorOverrides = snapshot.annotationTextBackgroundColorOverrides
        annotationTextFontSizeOverrides = snapshot.annotationTextFontSizeOverrides
        annotationTextAlignmentOverrides = snapshot.annotationTextAlignmentOverrides
        annotationColorOverrides = snapshot.annotationColorOverrides
        annotationStrokeWidthOverrides = snapshot.annotationStrokeWidthOverrides
        annotationBoxFillColorOverrides = snapshot.annotationBoxFillColorOverrides
        annotationBoxFillOpacityOverrides = snapshot.annotationBoxFillOpacityOverrides
        annotationBoxCornerRadiusOverrides = snapshot.annotationBoxCornerRadiusOverrides
        annotationDrawAutoSmoothOverrides = snapshot.annotationDrawAutoSmoothOverrides
        annotations = snapshot.annotations
        redactionRegions = snapshot.redactionRegions
        if isOriginalStyleLayoutLocked {
            applyOriginalLayoutLock()
        }
        if centeringEnabled, detectedSubjectCenterX != nil, detectedSubjectCenterY != nil {
            updateCenteringIndicator()
        } else {
            analyzeSubjectCentering()
        }
    }
}

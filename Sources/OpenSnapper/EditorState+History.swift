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

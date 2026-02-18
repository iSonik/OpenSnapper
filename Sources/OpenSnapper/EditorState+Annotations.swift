import CoreGraphics
import Foundation

extension EditorState {
    func setAnnotationTool(_ tool: AnnotationTool) {
        annotationTool = tool
        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
    }

    func beginAnnotationDrag(at point: CGPoint, in canvas: CGSize) {
        guard annotationTool != .none, canvas.width > 1, canvas.height > 1 else { return }
        recordUndoCheckpoint()
        let normalized = normalizedCanvasPoint(from: point, canvas: canvas)
        draftAnnotationStart = normalized
        draftAnnotationCurrent = normalized
    }

    func updateAnnotationDrag(at point: CGPoint, in canvas: CGSize) {
        guard draftAnnotationStart != nil, canvas.width > 1, canvas.height > 1 else { return }
        draftAnnotationCurrent = normalizedCanvasPoint(from: point, canvas: canvas)
    }

    func commitAnnotationDrag() {
        guard
            let start = draftAnnotationStart,
            let end = draftAnnotationCurrent,
            annotationTool != .none
        else {
            draftAnnotationStart = nil
            draftAnnotationCurrent = nil
            return
        }

        let distance = hypot(end.x - start.x, end.y - start.y)
        if distance >= 0.002 {
            let kind: Annotation.Kind = annotationTool == .arrow ? .arrow : .box
            annotations.append(Annotation(id: UUID(), kind: kind, start: start, end: end))
            setStatus(AppStrings.Messages.arrowAdded(for: kind == .arrow ? "Arrow" : "Box"))
        }

        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
    }

    func cancelAnnotationDrag() {
        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
    }

    func clearAnnotations() {
        guard !annotations.isEmpty else { return }
        recordUndoCheckpoint()
        annotations.removeAll()
        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
        setStatus(AppStrings.Messages.clearAnnotations)
    }

    func clearSensitiveRedactions() {
        guard !redactionRegions.isEmpty else { return }
        recordUndoCheckpoint()
        redactionRegions.removeAll()
        setStatus(AppStrings.Messages.clearRedactions)
    }

    func autoRedactSensitiveText() {
        guard let image = sourceImage else {
            setStatus(AppStrings.Messages.noImageSelected, isError: true)
            return
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            setStatus(AppStrings.Messages.redactionFailed("could not read image"), isError: true)
            return
        }

        setStatus(AppStrings.Messages.scanSensitiveText)
        Task.detached(priority: .userInitiated) { [cgImage] in
            let result = Result { try Self.detectSensitiveTextRegions(from: cgImage) }
            await MainActor.run {
                switch result {
                case .success(let regions):
                    guard !regions.isEmpty else {
                        self.setStatus(AppStrings.Messages.noSensitiveTextFound)
                        return
                    }
                    self.recordUndoCheckpoint()
                    self.redactionRegions = regions.map {
                        SensitiveRegion(id: UUID(), imageNormalizedRect: $0.standardized)
                    }
                    self.setStatus(AppStrings.Messages.addedRedactions(regions.count))
                    self.showToast(AppStrings.Messages.sensitiveTextRedacted, isError: false)
                case .failure(let error):
                    self.setStatus(AppStrings.Messages.redactionFailed(error.localizedDescription), isError: true)
                }
            }
        }
    }

    private func normalizedCanvasPoint(from point: CGPoint, canvas: CGSize) -> CGPoint {
        let x = min(max(point.x / max(canvas.width, 1), 0), 1)
        let y = min(max(point.y / max(canvas.height, 1), 0), 1)
        return CGPoint(x: x, y: y)
    }
}

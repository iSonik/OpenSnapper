import AppKit
import CoreGraphics
import Foundation

extension EditorState {
    func setAnnotationTool(_ tool: AnnotationTool) {
        annotationTool = tool
        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
        draftFreehandPoints = []
        if tool != .none {
            editingTextAnnotationID = nil
        }
    }

    func selectAnnotation(_ id: UUID?) {
        selectedAnnotationID = id
        if id == nil {
            editingTextAnnotationID = nil
        }
    }

    func beginAnnotationDrag(at point: CGPoint, in canvas: CGSize) {
        guard annotationTool == .box || annotationTool == .arrow || annotationTool == .lupe, canvas.width > 1, canvas.height > 1 else { return }
        recordUndoCheckpoint()
        let normalized = normalizedCanvasPoint(from: point, canvas: canvas)
        draftAnnotationStart = normalized
        draftAnnotationCurrent = normalized
    }

    func beginFreehandAnnotation(at point: CGPoint, in canvas: CGSize) {
        guard annotationTool == .draw, canvas.width > 1, canvas.height > 1 else { return }
        recordUndoCheckpoint()
        let normalized = normalizedCanvasPoint(from: point, canvas: canvas)
        draftFreehandPoints = [normalized]
    }

    func updateAnnotationDrag(at point: CGPoint, in canvas: CGSize) {
        guard let draftStart = draftAnnotationStart, canvas.width > 1, canvas.height > 1 else { return }
        let normalized = normalizedCanvasPoint(from: point, canvas: canvas)
        if annotationTool == .lupe {
            draftAnnotationCurrent = adjustedLupeCreationEnd(start: draftStart, end: normalized, in: canvas)
        } else {
            draftAnnotationCurrent = normalized
        }
    }

    func updateFreehandAnnotation(at point: CGPoint, in canvas: CGSize) {
        guard annotationTool == .draw, canvas.width > 1, canvas.height > 1 else { return }
        let normalized = normalizedCanvasPoint(from: point, canvas: canvas)
        if let last = draftFreehandPoints.last {
            let thresholdX = max(1.5 / canvas.width, 0.0006)
            let thresholdY = max(1.5 / canvas.height, 0.0006)
            if abs(normalized.x - last.x) < thresholdX, abs(normalized.y - last.y) < thresholdY {
                return
            }
        }
        draftFreehandPoints.append(normalized)
    }

    func commitAnnotationDrag() {
        guard
            let start = draftAnnotationStart,
            let end = draftAnnotationCurrent,
            annotationTool == .box || annotationTool == .arrow || annotationTool == .lupe
        else {
            draftAnnotationStart = nil
            draftAnnotationCurrent = nil
            return
        }

        let distance = hypot(end.x - start.x, end.y - start.y)
        if distance >= 0.002 {
            let kind: Annotation.Kind
            switch annotationTool {
            case .arrow:
                kind = .arrow
            case .lupe:
                kind = .lupe
            default:
                kind = .box
            }
            let id = UUID()
            annotations.append(
                Annotation(
                    id: id,
                    kind: kind,
                    stylePreset: annotationStylePreset,
                    start: start,
                    end: end,
                    text: nil,
                    textBoxWidth: kind == .lupe ? defaultLupeSourceRadiusNormalized(in: canvasSize) : nil,
                    textBoxHeight: nil
                )
            )
            storeStyleOverrides(for: id, kind: kind)
            setStatus(AppStrings.Messages.arrowAdded(for: kind.title))
            selectedAnnotationID = annotations.last?.id
        }

        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
    }

    func commitFreehandAnnotation() {
        guard annotationTool == .draw else {
            draftFreehandPoints = []
            return
        }

        defer { draftFreehandPoints = [] }
        guard draftFreehandPoints.count >= 2 else { return }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var pathLength: CGFloat = 0
        for index in draftFreehandPoints.indices {
            let point = draftFreehandPoints[index]
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
            if index > 0 {
                let prev = draftFreehandPoints[index - 1]
                pathLength += hypot(point.x - prev.x, point.y - prev.y)
            }
        }
        guard pathLength >= 0.003 else { return }

        let start = CGPoint(x: minX, y: minY)
        let end = CGPoint(x: maxX, y: maxY)
        let id = UUID()
        annotations.append(
            Annotation(
                id: id,
                kind: .draw,
                stylePreset: annotationStylePreset,
                start: start,
                end: end,
                text: nil,
                textBoxWidth: nil,
                textBoxHeight: nil,
                controlPoint: nil,
                points: draftFreehandPoints
            )
        )
        storeStyleOverrides(for: id, kind: .draw)
        selectedAnnotationID = id
        setStatus(AppStrings.Messages.arrowAdded(for: Annotation.Kind.draw.title))
    }

    func cancelAnnotationDrag() {
        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
    }

    func cancelFreehandAnnotation() {
        draftFreehandPoints = []
    }

    func addTextAnnotation(at point: CGPoint, in canvas: CGSize) {
        guard canvas.width > 1, canvas.height > 1 else { return }
        let normalized = normalizedCanvasPoint(from: point, canvas: canvas)
        let text = annotationTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = UUID()
        let defaultTextBoxWidth = min(max(180 / canvas.width, 44 / canvas.width), 1)
        let defaultTextBoxHeight = min(max(40 / canvas.height, 28 / canvas.height), 1)
        recordUndoCheckpoint()
        annotations.append(
            Annotation(
                id: id,
                kind: .text,
                stylePreset: annotationStylePreset,
                start: normalized,
                end: normalized,
                text: text.isEmpty ? "Text" : text,
                textBoxWidth: defaultTextBoxWidth,
                textBoxHeight: defaultTextBoxHeight,
                controlPoint: nil,
                points: []
            )
        )
        storeStyleOverrides(for: id, kind: .text)
        setStatus(AppStrings.Messages.arrowAdded(for: Annotation.Kind.text.title))
        selectedAnnotationID = id
        editingTextAnnotationID = nil
    }

    func beginEditingTextAnnotationIfHit(at point: CGPoint, in canvas: CGSize) -> Bool {
        guard canvas.width > 1, canvas.height > 1 else { return false }
        guard let annotation = hitTestTextAnnotation(at: point, in: canvas) else {
            editingTextAnnotationID = nil
            return false
        }
        recordUndoCheckpoint()
        selectedAnnotationID = annotation.id
        editingTextAnnotationID = annotation.id
        annotationTextDraft = annotation.text ?? "Text"
        return true
    }

    func updateTextAnnotation(_ id: UUID, text: String) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let current = annotations[index]
        guard current.kind == .text else { return }
        annotations[index] = Annotation(
            id: current.id,
            kind: current.kind,
            stylePreset: current.stylePreset,
            start: current.start,
            end: current.end,
            text: text,
            textBoxWidth: current.textBoxWidth,
            textBoxHeight: current.textBoxHeight,
            controlPoint: current.controlPoint,
            points: current.points
        )
        if editingTextAnnotationID == id {
            annotationTextDraft = text
        }
    }

    func finishEditingTextAnnotation() {
        guard let id = editingTextAnnotationID else { return }
        let trimmed = annotationTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        updateTextAnnotation(id, text: trimmed.isEmpty ? "Text" : trimmed)
        editingTextAnnotationID = nil
    }

    func annotationHitTarget(at point: CGPoint, in canvas: CGSize) -> AnnotationHitTarget? {
        guard canvas.width > 1, canvas.height > 1 else { return nil }

        if let selectedAnnotationID,
           let selected = annotations.first(where: { $0.id == selectedAnnotationID }),
           let handleTarget = annotationHandleHitTarget(for: selected, at: point, in: canvas)
        {
            return handleTarget
        }

        for annotation in annotations.reversed() {
            if let handleTarget = annotationHandleHitTarget(for: annotation, at: point, in: canvas) {
                return handleTarget
            }
            if annotationBodyHit(annotation, at: point, in: canvas) {
                return .body(annotation.id)
            }
        }
        return nil
    }

    func moveAnnotation(_ id: UUID, deltaX: CGFloat, deltaY: CGFloat, in canvas: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard canvas.width > 1, canvas.height > 1 else { return }

        let dx = deltaX / canvas.width
        let dy = deltaY / canvas.height
        let current = annotations[index]

        let movedStart = clampedNormalizedPoint(CGPoint(x: current.start.x + dx, y: current.start.y + dy))
        let movedEnd = clampedNormalizedPoint(CGPoint(x: current.end.x + dx, y: current.end.y + dy))
        let movedControlPoint = current.controlPoint.map {
            clampedNormalizedPoint(CGPoint(x: $0.x + dx, y: $0.y + dy))
        }
        let movedPoints = current.points.map {
            clampedNormalizedPoint(CGPoint(x: $0.x + dx, y: $0.y + dy))
        }

        annotations[index] = Annotation(
            id: current.id,
            kind: current.kind,
            stylePreset: current.stylePreset,
            start: movedStart,
            end: movedEnd,
            text: current.text,
            textBoxWidth: current.textBoxWidth,
            textBoxHeight: current.textBoxHeight,
            controlPoint: movedControlPoint,
            points: movedPoints
        )
    }

    func resizeBoxAnnotation(_ id: UUID, corner: AnnotationBoxCorner, to point: CGPoint, in canvas: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let current = annotations[index]
        guard current.kind == .box, canvas.width > 1, canvas.height > 1 else { return }

        let rect = normalizedBoxRect(for: current)
        let dragged = normalizedCanvasPoint(from: point, canvas: canvas)
        let fixedCorner: CGPoint
        switch corner {
        case .topLeft:
            fixedCorner = CGPoint(x: rect.maxX, y: rect.maxY)
        case .topRight:
            fixedCorner = CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomLeft:
            fixedCorner = CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomRight:
            fixedCorner = CGPoint(x: rect.minX, y: rect.minY)
        }

        var minX = min(fixedCorner.x, dragged.x)
        var maxX = max(fixedCorner.x, dragged.x)
        var minY = min(fixedCorner.y, dragged.y)
        var maxY = max(fixedCorner.y, dragged.y)

        let minWidth = max(6 / canvas.width, 0.002)
        let minHeight = max(6 / canvas.height, 0.002)
        if maxX - minX < minWidth {
            if fixedCorner.x <= dragged.x {
                maxX = minX + minWidth
            } else {
                minX = maxX - minWidth
            }
        }
        if maxY - minY < minHeight {
            if fixedCorner.y <= dragged.y {
                maxY = minY + minHeight
            } else {
                minY = maxY - minHeight
            }
        }

        let updatedRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        annotations[index] = Annotation(
            id: current.id,
            kind: current.kind,
            stylePreset: current.stylePreset,
            start: CGPoint(x: updatedRect.minX, y: updatedRect.minY),
            end: CGPoint(x: updatedRect.maxX, y: updatedRect.maxY),
            text: current.text,
            textBoxWidth: current.textBoxWidth,
            textBoxHeight: current.textBoxHeight,
            controlPoint: current.controlPoint,
            points: current.points
        )
    }

    func resizeArrowAnnotation(_ id: UUID, movingStart: Bool, to point: CGPoint, in canvas: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let current = annotations[index]
        guard (current.kind == .arrow || current.kind == .lupe), canvas.width > 1, canvas.height > 1 else { return }

        let normalized = normalizedCanvasPoint(from: point, canvas: canvas)
        annotations[index] = Annotation(
            id: current.id,
            kind: current.kind,
            stylePreset: current.stylePreset,
            start: movingStart ? normalized : current.start,
            end: movingStart ? current.end : normalized,
            text: current.text,
            textBoxWidth: current.textBoxWidth,
            textBoxHeight: current.textBoxHeight,
            controlPoint: current.controlPoint,
            points: current.points
        )
    }

    func resizeArrowBendAnnotation(_ id: UUID, to point: CGPoint, in canvas: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let current = annotations[index]
        guard current.kind == .arrow, canvas.width > 1, canvas.height > 1 else { return }
        let midpoint = normalizedCanvasPoint(from: point, canvas: canvas)
        let control = clampedNormalizedPoint(
            CGPoint(
                x: (2 * midpoint.x) - ((current.start.x + current.end.x) / 2),
                y: (2 * midpoint.y) - ((current.start.y + current.end.y) / 2)
            )
        )
        annotations[index] = Annotation(
            id: current.id,
            kind: current.kind,
            stylePreset: current.stylePreset,
            start: current.start,
            end: current.end,
            text: current.text,
            textBoxWidth: current.textBoxWidth,
            textBoxHeight: current.textBoxHeight,
            controlPoint: control,
            points: current.points
        )
    }

    func resizeLupeSourceRadiusAnnotation(_ id: UUID, to point: CGPoint, in canvas: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let current = annotations[index]
        guard current.kind == .lupe, canvas.width > 1, canvas.height > 1 else { return }

        let center = CGPoint(x: current.start.x * canvas.width, y: current.start.y * canvas.height)
        let rawRadius = hypot(point.x - center.x, point.y - center.y)
        let minDimension = max(min(canvas.width, canvas.height), 1)
        let normalized = min(
            lupeSourceRadiusNormalizedRange.upperBound,
            max(lupeSourceRadiusNormalizedRange.lowerBound, rawRadius / minDimension)
        )

        annotations[index] = Annotation(
            id: current.id,
            kind: current.kind,
            stylePreset: current.stylePreset,
            start: current.start,
            end: current.end,
            text: current.text,
            textBoxWidth: normalized,
            textBoxHeight: current.textBoxHeight,
            controlPoint: current.controlPoint,
            points: current.points
        )
    }

    func resizeTextAnnotationBox(_ id: UUID, handle: AnnotationTextHandleSide, to point: CGPoint, in canvas: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let current = annotations[index]
        guard current.kind == .text, canvas.width > 1, canvas.height > 1 else { return }

        let currentRect = textAnnotationVisibleRect(for: current, in: canvas)
        let metrics = textAnnotationMetrics(for: current)
        let minWidth = metrics.minBubbleWidth
        let minHeight = metrics.minBubbleHeight
        var left = currentRect.minX
        var right = currentRect.maxX
        var top = currentRect.minY
        var bottom = currentRect.maxY
        let x = min(max(point.x, 0), canvas.width)
        let y = min(max(point.y, 0), canvas.height)

        switch handle {
        case .left:
            left = min(x, right - minWidth)
        case .right:
            right = max(x, left + minWidth)
        case .top:
            top = min(y, bottom - minHeight)
        case .bottom:
            bottom = max(y, top + minHeight)
        }

        let center = CGPoint(x: (left + right) / 2, y: (top + bottom) / 2)
        let normalizedCenter = normalizedCanvasPoint(from: center, canvas: canvas)
        let normalizedWidth = min(max((right - left) / canvas.width, minWidth / canvas.width), 1)
        let normalizedHeight = min(max((bottom - top) / canvas.height, minHeight / canvas.height), 1)

        annotations[index] = Annotation(
            id: current.id,
            kind: current.kind,
            stylePreset: current.stylePreset,
            start: normalizedCenter,
            end: normalizedCenter,
            text: current.text,
            textBoxWidth: normalizedWidth,
            textBoxHeight: normalizedHeight,
            controlPoint: current.controlPoint,
            points: current.points
        )
    }

    func clearAnnotations() {
        guard !annotations.isEmpty else { return }
        recordUndoCheckpoint()
        annotations.removeAll()
        clearAllAnnotationStyleOverrides()
        selectedAnnotationID = nil
        editingTextAnnotationID = nil
        draftAnnotationStart = nil
        draftAnnotationCurrent = nil
        draftFreehandPoints = []
        setStatus(AppStrings.Messages.clearAnnotations)
    }

    func deleteSelectedAnnotation() {
        guard let selectedAnnotationID else { return }
        guard let index = annotations.firstIndex(where: { $0.id == selectedAnnotationID }) else {
            self.selectedAnnotationID = nil
            return
        }

        recordUndoCheckpoint()
        removeStyleOverrides(for: selectedAnnotationID)
        annotations.remove(at: index)
        self.selectedAnnotationID = nil
        editingTextAnnotationID = nil
        setStatus("Annotation deleted")
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

    private func clampedNormalizedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
    }

    private func hitTestTextAnnotation(at point: CGPoint, in canvas: CGSize) -> Annotation? {
        for annotation in annotations.reversed() where annotation.kind == .text {
            let rect = textAnnotationHitRect(for: annotation, in: canvas)
            if rect.contains(point) {
                return annotation
            }
        }
        return nil
    }

    private func textAnnotationHitRect(for annotation: Annotation, in canvas: CGSize) -> CGRect {
        textAnnotationVisibleRect(for: annotation, in: canvas).insetBy(dx: -4, dy: -4)
    }

    private func textAnnotationVisibleRect(for annotation: Annotation, in canvas: CGSize) -> CGRect {
        let center = CGPoint(x: annotation.start.x * canvas.width, y: annotation.start.y * canvas.height)
        let text = (annotation.text?.isEmpty == false ? annotation.text : "Text") ?? "Text"
        let metrics = textAnnotationMetrics(for: annotation)
        let font = NSFont.systemFont(ofSize: metrics.fontSize, weight: .semibold)

        let bubbleWidth: CGFloat
        let measuredTextHeight: CGFloat
        if let normalizedWidth = annotation.textBoxWidth {
            bubbleWidth = max(normalizedWidth * canvas.width, metrics.minBubbleWidth)
            let contentWidth = max(bubbleWidth - (metrics.horizontalPadding * 2), 8)
            let measured = (text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            measuredTextHeight = ceil(max(measured.height, font.capHeight))
        } else {
            let rawSize = (text as NSString).size(withAttributes: [.font: font])
            bubbleWidth = max(ceil(rawSize.width) + (metrics.horizontalPadding * 2), metrics.minBubbleWidth)
            measuredTextHeight = ceil(max(rawSize.height, font.capHeight))
        }

        let contentDrivenBubbleHeight = max(measuredTextHeight + (metrics.verticalPadding * 2), metrics.minBubbleHeight)
        let bubbleHeight: CGFloat
        if let normalizedHeight = annotation.textBoxHeight {
            bubbleHeight = max(contentDrivenBubbleHeight, normalizedHeight * canvas.height)
        } else {
            bubbleHeight = contentDrivenBubbleHeight
        }
        return CGRect(
            x: center.x - bubbleWidth / 2,
            y: center.y - bubbleHeight / 2,
            width: bubbleWidth,
            height: bubbleHeight
        )
    }

    private func annotationHandleHitTarget(for annotation: Annotation, at point: CGPoint, in canvas: CGSize) -> AnnotationHitTarget? {
        switch annotation.kind {
        case .box:
            let handleRadius: CGFloat = 8
            let rect = boxRectInCanvas(for: annotation, in: canvas)
            let handles: [(AnnotationBoxCorner, CGPoint)] = [
                (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
                (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
                (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
                (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY))
            ]
            if let matched = handles.first(where: { hypot($0.1.x - point.x, $0.1.y - point.y) <= handleRadius }) {
                return .boxCorner(annotation.id, matched.0)
            }
        case .arrow, .lupe:
            let handleRadius: CGFloat = 8
            let start = CGPoint(x: annotation.start.x * canvas.width, y: annotation.start.y * canvas.height)
            let end = CGPoint(x: annotation.end.x * canvas.width, y: annotation.end.y * canvas.height)
            if hypot(start.x - point.x, start.y - point.y) <= handleRadius {
                return .arrowStart(annotation.id)
            }
            if hypot(end.x - point.x, end.y - point.y) <= handleRadius {
                return .arrowEnd(annotation.id)
            }
            if annotation.kind == .arrow {
                let bendHandle = arrowBendHandlePoint(for: annotation, in: canvas)
                if hypot(bendHandle.x - point.x, bendHandle.y - point.y) <= 10 {
                    return .arrowBend(annotation.id)
                }
            }
            if annotation.kind == .lupe {
                let sourceRadius = lupeSourceRadius(for: annotation, in: canvas)
                let radiusHandle = CGPoint(x: start.x + sourceRadius, y: start.y)
                if hypot(radiusHandle.x - point.x, radiusHandle.y - point.y) <= 10 {
                    return .lupeRadius(annotation.id)
                }
            }
        case .draw:
            let handleRadius: CGFloat = 10
            let handle = drawMoveHandlePoint(for: annotation, in: canvas)
            if hypot(handle.x - point.x, handle.y - point.y) <= handleRadius {
                return .drawMove(annotation.id)
            }
        case .text:
            let handleRadius: CGFloat = 14
            let rect = textAnnotationVisibleRect(for: annotation, in: canvas)
            let left = CGPoint(x: rect.minX, y: rect.midY)
            let right = CGPoint(x: rect.maxX, y: rect.midY)
            let top = CGPoint(x: rect.midX, y: rect.minY)
            let bottom = CGPoint(x: rect.midX, y: rect.maxY)
            if hypot(left.x - point.x, left.y - point.y) <= handleRadius {
                return .textHandle(annotation.id, .left)
            }
            if hypot(right.x - point.x, right.y - point.y) <= handleRadius {
                return .textHandle(annotation.id, .right)
            }
            if hypot(top.x - point.x, top.y - point.y) <= handleRadius {
                return .textHandle(annotation.id, .top)
            }
            if hypot(bottom.x - point.x, bottom.y - point.y) <= handleRadius {
                return .textHandle(annotation.id, .bottom)
            }
        }

        return nil
    }

    private func annotationBodyHit(_ annotation: Annotation, at point: CGPoint, in canvas: CGSize) -> Bool {
        switch annotation.kind {
        case .box:
            let rect = boxRectInCanvas(for: annotation, in: canvas).insetBy(dx: -6, dy: -6)
            return rect.contains(point)
        case .arrow:
            let start = CGPoint(x: annotation.start.x * canvas.width, y: annotation.start.y * canvas.height)
            let end = CGPoint(x: annotation.end.x * canvas.width, y: annotation.end.y * canvas.height)
            if let control = annotation.controlPoint.map({ CGPoint(x: $0.x * canvas.width, y: $0.y * canvas.height) }) {
                return distanceFromPoint(point, toQuadraticCurveStart: start, control: control, end: end) <= 10
            }
            return distanceFromPoint(point, toSegmentStart: start, end: end) <= 10
        case .lupe:
            let source = CGPoint(x: annotation.start.x * canvas.width, y: annotation.start.y * canvas.height)
            let lens = CGPoint(x: annotation.end.x * canvas.width, y: annotation.end.y * canvas.height)
            let sourceRadius = lupeSourceRadius(for: annotation, in: canvas)
            let lensRadius = lupeLensRadius(for: annotation, in: canvas)
            if hypot(point.x - source.x, point.y - source.y) <= sourceRadius + 8 { return true }
            if hypot(point.x - lens.x, point.y - lens.y) <= lensRadius + 8 { return true }
            return distanceFromPoint(point, toSegmentStart: source, end: lens) <= 10
        case .draw:
            let points = annotation.points.map { CGPoint(x: $0.x * canvas.width, y: $0.y * canvas.height) }
            guard points.count >= 2 else { return false }
            let strokeWidth = annotationStrokeWidthOverrides[annotation.id] ?? annotationStrokeWidth
            return distanceFromPoint(point, toPolyline: points) <= max(10, strokeWidth + 6)
        case .text:
            return textAnnotationHitRect(for: annotation, in: canvas).contains(point)
        }
    }

    private func normalizedBoxRect(for annotation: Annotation) -> CGRect {
        CGRect(
            x: min(annotation.start.x, annotation.end.x),
            y: min(annotation.start.y, annotation.end.y),
            width: abs(annotation.end.x - annotation.start.x),
            height: abs(annotation.end.y - annotation.start.y)
        ).standardized
    }

    private func boxRectInCanvas(for annotation: Annotation, in canvas: CGSize) -> CGRect {
        let rect = normalizedBoxRect(for: annotation)
        return CGRect(
            x: rect.minX * canvas.width,
            y: rect.minY * canvas.height,
            width: rect.width * canvas.width,
            height: rect.height * canvas.height
        )
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentStart a: CGPoint, end b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0.0001 else {
            return hypot(point.x - a.x, point.y - a.y)
        }
        let t = min(max(((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared, 0), 1)
        let projection = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private func distanceFromPoint(_ point: CGPoint, toPolyline points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return .greatestFiniteMagnitude }
        var best = CGFloat.greatestFiniteMagnitude
        for index in 1..<points.count {
            best = min(best, distanceFromPoint(point, toSegmentStart: points[index - 1], end: points[index]))
        }
        return best
    }

    private func distanceFromPoint(_ point: CGPoint, toQuadraticCurveStart start: CGPoint, control: CGPoint, end: CGPoint) -> CGFloat {
        let samples = sampledQuadraticPoints(start: start, control: control, end: end, count: 24)
        return distanceFromPoint(point, toPolyline: samples)
    }

    private func arrowBendHandlePoint(for annotation: Annotation, in canvas: CGSize) -> CGPoint {
        let start = CGPoint(x: annotation.start.x * canvas.width, y: annotation.start.y * canvas.height)
        let end = CGPoint(x: annotation.end.x * canvas.width, y: annotation.end.y * canvas.height)
        guard let control = annotation.controlPoint else {
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        let controlCanvas = CGPoint(x: control.x * canvas.width, y: control.y * canvas.height)
        return CGPoint(
            x: ((start.x + end.x) * 0.25) + (controlCanvas.x * 0.5),
            y: ((start.y + end.y) * 0.25) + (controlCanvas.y * 0.5)
        )
    }

    private func sampledQuadraticPoints(start: CGPoint, control: CGPoint, end: CGPoint, count: Int) -> [CGPoint] {
        let sampleCount = max(count, 2)
        var result: [CGPoint] = []
        result.reserveCapacity(sampleCount + 1)
        for step in 0...sampleCount {
            let t = CGFloat(step) / CGFloat(sampleCount)
            let mt = 1 - t
            result.append(CGPoint(
                x: (mt * mt * start.x) + (2 * mt * t * control.x) + (t * t * end.x),
                y: (mt * mt * start.y) + (2 * mt * t * control.y) + (t * t * end.y)
            ))
        }
        return result
    }

    private func drawMoveHandlePoint(for annotation: Annotation, in canvas: CGSize) -> CGPoint {
        let points = annotation.points.map { CGPoint(x: $0.x * canvas.width, y: $0.y * canvas.height) }
        return polylineMidpoint(points) ?? CGPoint(
            x: annotation.start.x * canvas.width,
            y: annotation.start.y * canvas.height
        )
    }

    private func polylineMidpoint(_ points: [CGPoint]) -> CGPoint? {
        guard let first = points.first else { return nil }
        guard points.count >= 2 else { return first }

        var segmentLengths: [CGFloat] = []
        segmentLengths.reserveCapacity(points.count - 1)
        var total: CGFloat = 0
        for index in 1..<points.count {
            let a = points[index - 1]
            let b = points[index]
            let length = hypot(b.x - a.x, b.y - a.y)
            segmentLengths.append(length)
            total += length
        }

        guard total > 0.001 else { return points[points.count / 2] }
        let target = total * 0.5
        var traversed: CGFloat = 0

        for index in 1..<points.count {
            let segmentLength = segmentLengths[index - 1]
            let nextTraversed = traversed + segmentLength
            if target <= nextTraversed, segmentLength > 0.001 {
                let t = (target - traversed) / segmentLength
                let a = points[index - 1]
                let b = points[index]
                return CGPoint(
                    x: a.x + ((b.x - a.x) * t),
                    y: a.y + ((b.y - a.y) * t)
                )
            }
            traversed = nextTraversed
        }

        return points.last
    }

    private var lupeSourceRadiusNormalizedRange: ClosedRange<CGFloat> {
        0.02...0.22
    }

    private func defaultLupeSourceRadiusNormalized(in canvas: CGSize) -> CGFloat {
        let minDimension = max(min(canvas.width, canvas.height), 1)
        let normalized = max(24 / minDimension, 0.05)
        return min(lupeSourceRadiusNormalizedRange.upperBound, max(lupeSourceRadiusNormalizedRange.lowerBound, normalized))
    }

    private func lupeSourceRadius(for annotation: Annotation, in canvas: CGSize) -> CGFloat {
        let minDimension = max(min(canvas.width, canvas.height), 1)
        let normalized = annotation.textBoxWidth ?? defaultLupeSourceRadiusNormalized(in: canvas)
        let clamped = min(lupeSourceRadiusNormalizedRange.upperBound, max(lupeSourceRadiusNormalizedRange.lowerBound, normalized))
        return clamped * minDimension
    }

    private func lupeLensRadius(for annotation: Annotation, in canvas: CGSize) -> CGFloat {
        max(44, lupeSourceRadius(for: annotation, in: canvas) * 1.7)
    }

    private func adjustedLupeCreationEnd(start: CGPoint, end: CGPoint, in canvas: CGSize) -> CGPoint {
        let startPoint = CGPoint(x: start.x * canvas.width, y: start.y * canvas.height)
        let endPoint = CGPoint(x: end.x * canvas.width, y: end.y * canvas.height)
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let rawDistance = hypot(dx, dy)

        let sourceRadius = defaultLupeSourceRadiusNormalized(in: canvas) * max(min(canvas.width, canvas.height), 1)
        let lensRadius = max(44, sourceRadius * 1.7)
        let minimumDistance = sourceRadius + lensRadius + 22
        guard rawDistance > 0.001, rawDistance < minimumDistance else { return end }

        let ux = dx / rawDistance
        let uy = dy / rawDistance
        let expanded = CGPoint(
            x: startPoint.x + ux * minimumDistance,
            y: startPoint.y + uy * minimumDistance
        )
        return normalizedCanvasPoint(from: expanded, canvas: canvas)
    }

    private func storeStyleOverrides(for id: UUID, kind: Annotation.Kind) {
        annotationColorOverrides[id] = annotationCustomColor
        annotationStrokeWidthOverrides[id] = annotationStrokeWidth
        annotationBoxFillColorOverrides[id] = annotationBoxFillColor
        annotationBoxFillOpacityOverrides[id] = annotationBoxFillOpacity
        annotationBoxCornerRadiusOverrides[id] = annotationBoxCornerRadius
        if kind == .draw {
            annotationDrawAutoSmoothOverrides[id] = annotationDrawAutoSmooth
        }
        if kind == .text {
            annotationTextFontColorOverrides[id] = annotationTextDefaultFontColor
            annotationTextBackgroundColorOverrides[id] = annotationTextDefaultBackgroundColor
            annotationTextFontSizeOverrides[id] = annotationTextDefaultFontSize
            annotationTextAlignmentOverrides[id] = annotationTextDefaultAlignment
        }
    }

    private func removeStyleOverrides(for id: UUID) {
        annotationTextFontColorOverrides.removeValue(forKey: id)
        annotationTextBackgroundColorOverrides.removeValue(forKey: id)
        annotationTextFontSizeOverrides.removeValue(forKey: id)
        annotationTextAlignmentOverrides.removeValue(forKey: id)
        annotationColorOverrides.removeValue(forKey: id)
        annotationStrokeWidthOverrides.removeValue(forKey: id)
        annotationBoxFillColorOverrides.removeValue(forKey: id)
        annotationBoxFillOpacityOverrides.removeValue(forKey: id)
        annotationBoxCornerRadiusOverrides.removeValue(forKey: id)
        annotationDrawAutoSmoothOverrides.removeValue(forKey: id)
    }

    private func clearAllAnnotationStyleOverrides() {
        annotationTextFontColorOverrides.removeAll()
        annotationTextBackgroundColorOverrides.removeAll()
        annotationTextFontSizeOverrides.removeAll()
        annotationTextAlignmentOverrides.removeAll()
        annotationColorOverrides.removeAll()
        annotationStrokeWidthOverrides.removeAll()
        annotationBoxFillColorOverrides.removeAll()
        annotationBoxFillOpacityOverrides.removeAll()
        annotationBoxCornerRadiusOverrides.removeAll()
        annotationDrawAutoSmoothOverrides.removeAll()
    }

    private func textAnnotationMetrics(for annotation: Annotation? = nil) -> (
        fontSize: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        minBubbleWidth: CGFloat,
        minBubbleHeight: CGFloat
    ) {
        let fontSize = annotation.map { annotationTextFontSizeOverrides[$0.id] ?? annotationTextDefaultFontSize } ?? annotationTextDefaultFontSize
        return (fontSize: fontSize, horizontalPadding: 10, verticalPadding: 6, minBubbleWidth: 44, minBubbleHeight: 28)
    }
}

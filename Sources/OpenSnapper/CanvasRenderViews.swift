import AppKit
import SwiftUI

struct ExportCanvasView: View {
    let image: NSImage
    @ObservedObject var editor: EditorState
    let forExport: Bool

    var body: some View {
        ZStack {
            if editor.backgroundStyle == .original {
                Color.clear
            } else {
                CanvasBackgroundView(editor: editor)
            }
            styledImageLayer
                .padding(editor.canvasPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            CanvasAnnotationsOverlayView(editor: editor, forExport: forExport)
                .allowsHitTesting(!forExport)
        }
        .modifier(CanvasOuterClipModifier(editor: editor))
    }

    private var baseImageContent: some View {
        Group {
            if forExport {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                StaticRasterImageView(image: image)
            }
        }
    }

    private var styledImageLayer: some View {
        GeometryReader { geometry in
            let fitted = fittedImageSize(in: geometry.size)
            ZStack {
                baseImageContent
                    .frame(width: fitted.width, height: fitted.height)
                    .scaleEffect(editor.imageScale)
                    .offset(x: editor.imageOffsetX, y: editor.imageOffsetY)
                    .clipShape(RoundedRectangle(cornerRadius: activeImageCornerRadius, style: .continuous))
                    .shadow(color: shadowColor, radius: editor.shadowRadius, y: shadowYOffset)

                if !forExport {
                    RoundedRectangle(cornerRadius: activeImageCornerRadius, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: activeImageCornerRadius, style: .continuous)
                                .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .blur(radius: 0.2)
                        )
                        .frame(width: fitted.width, height: fitted.height)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var activeImageCornerRadius: CGFloat {
        if editor.isOriginalStyleLayoutLocked {
            return max(editor.outerCornerRadius, 0)
        }
        return max(editor.imageCornerRadius, 0)
    }

    private func fittedImageSize(in availableSize: CGSize) -> CGSize {
        let width = max(availableSize.width, 1)
        let height = max(availableSize.height, 1)
        let imageWidth = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        let imageAspect = imageWidth / imageHeight
        let containerAspect = width / height

        if containerAspect > imageAspect {
            let fittedHeight = height
            return CGSize(width: fittedHeight * imageAspect, height: fittedHeight)
        } else {
            let fittedWidth = width
            return CGSize(width: fittedWidth, height: fittedWidth / imageAspect)
        }
    }

    private var shadowColor: Color {
        if editor.shadowRadius <= 0 || editor.shadowOpacity <= 0 {
            return .clear
        }
        return .black.opacity(editor.shadowOpacity)
    }

    private var shadowYOffset: CGFloat {
        0
    }
}

private struct CanvasAnnotationsOverlayView: View {
    @ObservedObject var editor: EditorState
    let forExport: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(editor.annotations) { annotation in
                    annotationView(annotation, in: geometry.size)
                }

                if
                    let start = editor.draftAnnotationStart,
                    let end = editor.draftAnnotationCurrent,
                    (editor.annotationTool == .box || editor.annotationTool == .arrow || editor.annotationTool == .lupe)
                {
                    annotationView(
                        EditorState.Annotation(
                            id: UUID(),
                            kind: editor.annotationTool == .arrow ? .arrow : (editor.annotationTool == .lupe ? .lupe : .box),
                            stylePreset: editor.annotationStylePreset,
                            start: start,
                            end: end,
                            text: nil,
                            textBoxWidth: editor.annotationTool == .lupe ? defaultLupeSourceRadiusNormalized(in: geometry.size) : nil,
                            textBoxHeight: nil
                        ),
                        in: geometry.size,
                        isDraft: true
                    )
                }

                if editor.annotationTool == .draw, editor.draftFreehandPoints.count >= 2 {
                    let points = editor.draftFreehandPoints
                    let first = points.first ?? .zero
                    let last = points.last ?? first
                    annotationView(
                        EditorState.Annotation(
                            id: UUID(),
                            kind: .draw,
                            stylePreset: editor.annotationStylePreset,
                            start: first,
                            end: last,
                            text: nil,
                            textBoxWidth: nil,
                            textBoxHeight: nil,
                            controlPoint: nil,
                            points: points
                        ),
                        in: geometry.size,
                        isDraft: true
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func annotationView(_ annotation: EditorState.Annotation, in canvasSize: CGSize, isDraft: Bool = false) -> some View {
        let style = AnnotationVisualStyle(
            preset: annotation.stylePreset,
            customColor: annotationCustomColor(for: annotation.id),
            boxFillColor: annotationBoxFillColor(for: annotation.id),
            boxFillOpacity: annotationBoxFillOpacity(for: annotation.id),
            lineWidth: annotationStrokeWidth(for: annotation.id),
            boxCornerRadius: annotationBoxCornerRadius(for: annotation.id),
            isDraft: isDraft
        )
        switch annotation.kind {
        case .box:
            let rect = normalizedRect(annotation.start, annotation.end, in: canvasSize)
            RoundedRectangle(cornerRadius: style.boxCornerRadius, style: .continuous)
                .fill(style.boxFill)
                .overlay(
                    RoundedRectangle(cornerRadius: style.boxCornerRadius, style: .continuous)
                        .stroke(style.stroke, lineWidth: style.lineWidth)
                )
                .overlay {
                    if !forExport, editor.selectedAnnotationID == annotation.id {
                        RoundedRectangle(cornerRadius: style.boxCornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        let handles = boxHandlePoints(for: rect)
                        ForEach(Array(handles.enumerated()), id: \.offset) { _, handle in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(style.stroke, lineWidth: 2))
                                .position(x: handle.x, y: handle.y)
                        }
                    }
                }
                .frame(width: max(rect.width, style.lineWidth), height: max(rect.height, style.lineWidth))
                .position(x: rect.midX, y: rect.midY)

        case .arrow:
            let start = canvasPoint(annotation.start, in: canvasSize)
            let end = canvasPoint(annotation.end, in: canvasSize)
            let bendHandle = arrowBendHandlePoint(for: annotation, in: canvasSize)
            ZStack {
                if let control = annotation.controlPoint.map({ canvasPoint($0, in: canvasSize) }) {
                    CurvedCanvasArrowShape(
                        start: start,
                        control: control,
                        end: end,
                        headLength: style.arrowHeadLength,
                        headAngle: .pi / 7
                    )
                    .stroke(style.stroke, style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round))
                } else {
                    CanvasArrowShape(
                        start: start,
                        end: end,
                        headLength: style.arrowHeadLength,
                        headAngle: .pi / 7
                    )
                    .stroke(style.stroke, style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round))
                }

                if !forExport, editor.selectedAnnotationID == annotation.id {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(style.stroke, lineWidth: 2))
                        .position(x: start.x, y: start.y)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(style.stroke, lineWidth: 2))
                        .position(x: end.x, y: end.y)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(style.stroke, lineWidth: 2))
                        .position(x: bendHandle.x, y: bendHandle.y)
                }
            }

        case .draw:
            let points = annotation.points.map { canvasPoint($0, in: canvasSize) }
            if points.count >= 2 {
                (drawAutoSmoothEnabled(for: annotation.id) ? smoothStrokePath(points) : polylineStrokePath(points))
                    .stroke(style.stroke, style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round))
                    .overlay {
                        if !forExport, editor.selectedAnnotationID == annotation.id {
                            let center = drawMoveHandlePoint(for: points)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(style.stroke, lineWidth: 2))
                                .position(x: center.x, y: center.y)
                        }
                    }
            }

        case .lupe:
            let source = canvasPoint(annotation.start, in: canvasSize)
            let lens = canvasPoint(annotation.end, in: canvasSize)
            let sourceRadius = lupeSourceRadius(for: annotation, in: canvasSize)
            let lensRadius = lupeLensRadius(for: annotation, in: canvasSize)
            let connector = lupeConnector(source: source, lens: lens, sourceRadius: sourceRadius, lensRadius: lensRadius)
            let selected = !forExport && editor.selectedAnnotationID == annotation.id
            let radiusHandlePoint = CGPoint(x: source.x + sourceRadius, y: source.y)

            ZStack {
                if let connector {
                    Path { path in
                        path.move(to: connector.start)
                        path.addLine(to: connector.end)
                    }
                    .stroke(style.stroke, style: StrokeStyle(lineWidth: max(2, style.lineWidth - 0.5), lineCap: .round, lineJoin: .round))
                }

                lupeLensView(
                    at: lens,
                    sourcePoint: source,
                    lensRadius: lensRadius,
                    canvasSize: canvasSize,
                    style: style
                )

                Circle()
                    .fill(style.boxFill.opacity(0.25))
                    .overlay(
                        Circle()
                            .stroke(style.stroke, lineWidth: max(2, style.lineWidth - 0.5))
                    )
                    .frame(width: sourceRadius * 2, height: sourceRadius * 2)
                    .position(x: source.x, y: source.y)

                if selected {
                    Circle()
                        .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .frame(width: sourceRadius * 2 + 6, height: sourceRadius * 2 + 6)
                        .position(x: source.x, y: source.y)
                    Circle()
                        .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .frame(width: lensRadius * 2 + 6, height: lensRadius * 2 + 6)
                        .position(x: lens.x, y: lens.y)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(style.stroke, lineWidth: 2))
                        .position(x: source.x, y: source.y)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(style.stroke, lineWidth: 2))
                        .position(x: lens.x, y: lens.y)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(style.stroke, lineWidth: 1.8)
                        )
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(style.stroke)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .position(x: radiusHandlePoint.x, y: radiusHandlePoint.y)
                }
            }

        case .text:
            let point = canvasPoint(annotation.start, in: canvasSize)
            let selected = !forExport && editor.selectedAnnotationID == annotation.id
            let textFontSize = annotationTextFontSize(for: annotation.id, fallback: editor.annotationTextDefaultFontSize)
            let textForeground = annotationTextForeground(for: annotation.id, fallback: editor.annotationTextDefaultFontColor)
            let textBackground = annotationTextBackground(for: annotation.id, fallback: editor.annotationTextDefaultBackgroundColor)
            let textAlignment = annotationTextAlignment(for: annotation.id)
            let contentWidth = textContentWidth(for: annotation, style: style, in: canvasSize)
            let contentHeight = textContentHeight(for: annotation, style: style, in: canvasSize)
            if !forExport, editor.editingTextAnnotationID == annotation.id {
                InlineAnnotationTextEditor(
                    text: textBinding(for: annotation.id),
                    fontSize: textFontSize,
                    textColor: NSColor(textForeground),
                    alignment: textAlignment.nsTextAlignment,
                    preferredContentWidth: contentWidth,
                    preferredContentHeight: contentHeight,
                    onCommit: {
                        editor.finishEditingTextAnnotation()
                    }
                )
                    .frame(width: contentWidth, alignment: textAlignment.frameAlignment)
                    .frame(height: contentHeight, alignment: textAlignment.frameAlignment)
                    .padding(.horizontal, style.textHorizontalPadding)
                    .padding(.vertical, style.textVerticalPadding)
                    .background(textBackground, in: RoundedRectangle(cornerRadius: style.textCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.textCornerRadius, style: .continuous)
                            .stroke(style.stroke, lineWidth: max(1, style.lineWidth * 0.7))
                    )
                    .overlay {
                        if selected {
                            textSelectionHandlesOverlay(annotation: annotation, style: style, canvasSize: canvasSize)
                        }
                    }
                    .fixedSize(horizontal: contentWidth == nil, vertical: contentHeight == nil)
                    .position(x: point.x, y: point.y)
            } else {
                Text(annotation.text ?? "Text")
                    .font(.system(size: textFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(textForeground)
                    .multilineTextAlignment(textAlignment.swiftUITextAlignment)
                    .lineLimit(nil)
                    .frame(width: contentWidth, alignment: textAlignment.frameAlignment)
                    .frame(minHeight: contentHeight, alignment: textAlignment.frameAlignment)
                    .padding(.horizontal, style.textHorizontalPadding)
                    .padding(.vertical, style.textVerticalPadding)
                    .background(textBackground, in: RoundedRectangle(cornerRadius: style.textCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.textCornerRadius, style: .continuous)
                            .stroke(style.stroke.opacity(0.65), lineWidth: max(1, style.lineWidth * 0.5))
                    )
                    .overlay {
                        if selected {
                            textSelectionHandlesOverlay(annotation: annotation, style: style, canvasSize: canvasSize)
                        }
                    }
                    .fixedSize(horizontal: contentWidth == nil, vertical: contentHeight == nil)
                    .position(x: point.x, y: point.y)
            }
        }
    }

    private func canvasPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func arrowBendHandlePoint(for annotation: EditorState.Annotation, in canvasSize: CGSize) -> CGPoint {
        let start = canvasPoint(annotation.start, in: canvasSize)
        let end = canvasPoint(annotation.end, in: canvasSize)
        guard let control = annotation.controlPoint else {
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        let controlCanvas = canvasPoint(control, in: canvasSize)
        return CGPoint(
            x: ((start.x + end.x) * 0.25) + (controlCanvas.x * 0.5),
            y: ((start.y + end.y) * 0.25) + (controlCanvas.y * 0.5)
        )
    }

    private func annotationCustomColor(for id: UUID) -> Color {
        editor.annotationColorOverrides[id] ?? editor.annotationCustomColor
    }

    private func annotationStrokeWidth(for id: UUID) -> CGFloat {
        editor.annotationStrokeWidthOverrides[id] ?? editor.annotationStrokeWidth
    }

    private func annotationBoxFillColor(for id: UUID) -> Color {
        editor.annotationBoxFillColorOverrides[id] ?? editor.annotationBoxFillColor
    }

    private func annotationBoxFillOpacity(for id: UUID) -> Double {
        editor.annotationBoxFillOpacityOverrides[id] ?? editor.annotationBoxFillOpacity
    }

    private func annotationBoxCornerRadius(for id: UUID) -> CGFloat {
        editor.annotationBoxCornerRadiusOverrides[id] ?? editor.annotationBoxCornerRadius
    }

    private func annotationTextForeground(for id: UUID, fallback: Color) -> Color {
        editor.annotationTextFontColorOverrides[id] ?? fallback
    }

    private func annotationTextBackground(for id: UUID, fallback: Color) -> Color {
        editor.annotationTextBackgroundColorOverrides[id] ?? fallback
    }

    private func annotationTextFontSize(for id: UUID, fallback: CGFloat) -> CGFloat {
        editor.annotationTextFontSizeOverrides[id] ?? fallback
    }

    private func annotationTextAlignment(for id: UUID) -> EditorState.AnnotationTextAlignment {
        editor.annotationTextAlignmentOverrides[id] ?? editor.annotationTextDefaultAlignment
    }

    private func drawAutoSmoothEnabled(for id: UUID) -> Bool {
        editor.annotationDrawAutoSmoothOverrides[id] ?? editor.annotationDrawAutoSmooth
    }

    private func drawMoveHandlePoint(for points: [CGPoint]) -> CGPoint {
        polylineMidpoint(points) ?? (points.first ?? .zero)
    }

    private func polylineMidpoint(_ points: [CGPoint]) -> CGPoint? {
        guard let first = points.first else { return nil }
        guard points.count >= 2 else { return first }

        var lengths: [CGFloat] = []
        lengths.reserveCapacity(points.count - 1)
        var total: CGFloat = 0
        for index in 1..<points.count {
            let a = points[index - 1]
            let b = points[index]
            let length = hypot(b.x - a.x, b.y - a.y)
            lengths.append(length)
            total += length
        }

        guard total > 0.001 else { return points[points.count / 2] }
        let target = total * 0.5
        var traversed: CGFloat = 0

        for index in 1..<points.count {
            let length = lengths[index - 1]
            let nextTraversed = traversed + length
            if target <= nextTraversed, length > 0.001 {
                let t = (target - traversed) / length
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

    private func polylineStrokePath(_ points: [CGPoint]) -> Path {
        guard let first = points.first else { return Path() }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func smoothStrokePath(_ points: [CGPoint]) -> Path {
        let smoothedPoints = averagedStrokePoints(points)
        guard let first = smoothedPoints.first else { return Path() }
        guard smoothedPoints.count > 1 else {
            var path = Path()
            path.addEllipse(in: CGRect(x: first.x - 1, y: first.y - 1, width: 2, height: 2))
            return path
        }

        var path = Path()
        path.move(to: first)

        if smoothedPoints.count == 2 {
            path.addLine(to: smoothedPoints[1])
            return path
        }

        for index in 1..<(smoothedPoints.count - 1) {
            let current = smoothedPoints[index]
            let next = smoothedPoints[index + 1]
            let midpoint = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: midpoint, control: current)
        }

        if let last = smoothedPoints.last, let penultimate = smoothedPoints.dropLast().last {
            path.addQuadCurve(to: last, control: penultimate)
        }
        return path
    }

    private func averagedStrokePoints(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 4 else { return points }
        var output = points
        let passes = points.count >= 10 ? 3 : 2

        for _ in 0..<passes {
            let input = output
            for index in 1..<(input.count - 1) {
                let prev = input[index - 1]
                let current = input[index]
                let next = input[index + 1]

                if index >= 2, index <= input.count - 3 {
                    let prev2 = input[index - 2]
                    let next2 = input[index + 2]
                    output[index] = CGPoint(
                        x: (prev2.x * 0.12) + (prev.x * 0.22) + (current.x * 0.32) + (next.x * 0.22) + (next2.x * 0.12),
                        y: (prev2.y * 0.12) + (prev.y * 0.22) + (current.y * 0.32) + (next.y * 0.22) + (next2.y * 0.12)
                    )
                } else {
                    output[index] = CGPoint(
                        x: (prev.x * 0.3) + (current.x * 0.4) + (next.x * 0.3),
                        y: (prev.y * 0.3) + (current.y * 0.4) + (next.y * 0.3)
                    )
                }
            }
        }
        return output
    }

    private func normalizedRect(_ a: CGPoint, _ b: CGPoint, in size: CGSize) -> CGRect {
        let p1 = canvasPoint(a, in: size)
        let p2 = canvasPoint(b, in: size)
        return CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        ).standardized
    }

    private func textBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { editor.annotations.first(where: { $0.id == id })?.text ?? "" },
            set: { editor.updateTextAnnotation(id, text: $0) }
        )
    }

    private func boxHandlePoints(for rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: 0, y: 0),
            CGPoint(x: rect.width, y: 0),
            CGPoint(x: 0, y: rect.height),
            CGPoint(x: rect.width, y: rect.height)
        ]
    }

    private func textContentWidth(for annotation: EditorState.Annotation, style: AnnotationVisualStyle, in canvasSize: CGSize) -> CGFloat? {
        guard let normalizedWidth = annotation.textBoxWidth else { return nil }
        let bubbleWidth = max(normalizedWidth * canvasSize.width, 44)
        return max(bubbleWidth - (style.textHorizontalPadding * 2), 8)
    }

    private func textContentHeight(for annotation: EditorState.Annotation, style: AnnotationVisualStyle, in canvasSize: CGSize) -> CGFloat? {
        guard let normalizedHeight = annotation.textBoxHeight else { return nil }
        let bubbleHeight = max(normalizedHeight * canvasSize.height, 28)
        return max(bubbleHeight - (style.textVerticalPadding * 2), 16)
    }

    @ViewBuilder
    private func textSelectionHandlesOverlay(
        annotation: EditorState.Annotation,
        style: AnnotationVisualStyle,
        canvasSize: CGSize
    ) -> some View {
        let rect = textVisibleRect(for: annotation, style: style, in: canvasSize)
        RoundedRectangle(cornerRadius: style.textCornerRadius, style: .continuous)
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))

        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(style.stroke, lineWidth: 2))
            .position(x: 0, y: rect.height / 2)

        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(style.stroke, lineWidth: 2))
            .position(x: rect.width, y: rect.height / 2)

        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(style.stroke, lineWidth: 2))
            .position(x: rect.width / 2, y: 0)

        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(style.stroke, lineWidth: 2))
            .position(x: rect.width / 2, y: rect.height)
    }

    private func textVisibleRect(for annotation: EditorState.Annotation, style: AnnotationVisualStyle, in canvasSize: CGSize) -> CGRect {
        let center = canvasPoint(annotation.start, in: canvasSize)
        let text = (annotation.text?.isEmpty == false ? annotation.text : "Text") ?? "Text"
        let resolvedFontSize = annotationTextFontSize(for: annotation.id, fallback: style.textFontSize)
        let font = NSFont.systemFont(ofSize: resolvedFontSize, weight: .semibold)

        let bubbleWidth: CGFloat
        let measuredTextHeight: CGFloat
        if let contentWidth = textContentWidth(for: annotation, style: style, in: canvasSize) {
            bubbleWidth = contentWidth + (style.textHorizontalPadding * 2)
            let measured = (text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            measuredTextHeight = ceil(max(measured.height, font.capHeight))
        } else {
            let rawSize = (text as NSString).size(withAttributes: [.font: font])
            bubbleWidth = max(ceil(rawSize.width) + (style.textHorizontalPadding * 2), 44)
            measuredTextHeight = ceil(max(rawSize.height, font.capHeight))
        }

        let contentDrivenHeight = max(measuredTextHeight + (style.textVerticalPadding * 2), 28)
        let bubbleHeight: CGFloat
        if let normalizedHeight = annotation.textBoxHeight {
            bubbleHeight = max(contentDrivenHeight, normalizedHeight * canvasSize.height)
        } else {
            bubbleHeight = contentDrivenHeight
        }
        return CGRect(
            x: center.x - (bubbleWidth / 2),
            y: center.y - (bubbleHeight / 2),
            width: bubbleWidth,
            height: bubbleHeight
        )
    }

    private var lupeSourceRadiusNormalizedRange: ClosedRange<CGFloat> {
        0.02...0.22
    }

    private func defaultLupeSourceRadiusNormalized(in canvasSize: CGSize) -> CGFloat {
        let minDimension = max(min(canvasSize.width, canvasSize.height), 1)
        let normalized = max(24 / minDimension, 0.05)
        return min(lupeSourceRadiusNormalizedRange.upperBound, max(lupeSourceRadiusNormalizedRange.lowerBound, normalized))
    }

    private func lupeSourceRadius(for annotation: EditorState.Annotation, in canvasSize: CGSize) -> CGFloat {
        let minDimension = max(min(canvasSize.width, canvasSize.height), 1)
        let normalized = annotation.textBoxWidth ?? defaultLupeSourceRadiusNormalized(in: canvasSize)
        let clamped = min(lupeSourceRadiusNormalizedRange.upperBound, max(lupeSourceRadiusNormalizedRange.lowerBound, normalized))
        return clamped * minDimension
    }

    private func lupeLensRadius(for annotation: EditorState.Annotation, in canvasSize: CGSize) -> CGFloat {
        max(44, lupeSourceRadius(for: annotation, in: canvasSize) * 1.7)
    }

    private var lupeMagnification: CGFloat { 2.2 }

    private func lupeConnector(
        source: CGPoint,
        lens: CGPoint,
        sourceRadius: CGFloat,
        lensRadius: CGFloat
    ) -> (start: CGPoint, end: CGPoint)? {
        let dx = lens.x - source.x
        let dy = lens.y - source.y
        let length = hypot(dx, dy)
        guard length > 0.001 else { return nil }
        let ux = dx / length
        let uy = dy / length
        return (
            start: CGPoint(x: source.x + ux * sourceRadius, y: source.y + uy * sourceRadius),
            end: CGPoint(x: lens.x - ux * lensRadius, y: lens.y - uy * lensRadius)
        )
    }

    @ViewBuilder
    private func lupeLensView(
        at lensCenter: CGPoint,
        sourcePoint: CGPoint,
        lensRadius: CGFloat,
        canvasSize: CGSize,
        style: AnnotationVisualStyle
    ) -> some View {
        let diameter = lensRadius * 2
        let fill = Circle().fill(Color.black.opacity(forExport ? 0.12 : 0.22))

        ZStack {
            fill

            if let image = editor.sourceImage,
               let baseImageRect = lupeBaseImageRect(for: image, in: canvasSize)
            {
                lupeMagnifiedImage(
                    image: image,
                    sourcePoint: sourcePoint,
                    baseImageRect: baseImageRect,
                    lensRadius: lensRadius
                )
                .clipShape(Circle())
            }

            Circle()
                .stroke(style.stroke, lineWidth: max(2, style.lineWidth - 0.5))
        }
        .frame(width: diameter, height: diameter)
        .position(x: lensCenter.x, y: lensCenter.y)
    }

    private func lupeBaseImageRect(for image: NSImage, in canvasSize: CGSize) -> CGRect? {
        let availableWidth = max(1, canvasSize.width - (editor.canvasPadding * 2))
        let availableHeight = max(1, canvasSize.height - (editor.canvasPadding * 2))
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

        let x = (canvasSize.width - fitted.width) / 2
        let y = (canvasSize.height - fitted.height) / 2
        return CGRect(x: x, y: y, width: fitted.width, height: fitted.height)
    }

    @ViewBuilder
    private func lupeMagnifiedImage(
        image: NSImage,
        sourcePoint: CGPoint,
        baseImageRect: CGRect,
        lensRadius: CGFloat
    ) -> some View {
        let effectiveScale = max(editor.imageScale, 0.0001)
        let transformedCenter = CGPoint(
            x: baseImageRect.midX + editor.imageOffsetX,
            y: baseImageRect.midY + editor.imageOffsetY
        )
        let sourceDelta = CGPoint(
            x: sourcePoint.x - transformedCenter.x,
            y: sourcePoint.y - transformedCenter.y
        )
        let pointInBaseCanvas = CGPoint(
            x: baseImageRect.midX + (sourceDelta.x / effectiveScale),
            y: baseImageRect.midY + (sourceDelta.y / effectiveScale)
        )
        let localPoint = CGPoint(
            x: pointInBaseCanvas.x - baseImageRect.minX,
            y: pointInBaseCanvas.y - baseImageRect.minY
        )
        let totalScale = effectiveScale * lupeMagnification
        let origin = CGPoint(
            x: lensRadius - (localPoint.x * totalScale),
            y: lensRadius - (localPoint.y * totalScale)
        )

        ZStack(alignment: .topLeading) {
            if forExport {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: baseImageRect.width, height: baseImageRect.height)
                    .scaleEffect(totalScale, anchor: .topLeading)
                    .offset(x: origin.x, y: origin.y)
            } else {
                StaticRasterImageView(image: image)
                    .frame(width: baseImageRect.width, height: baseImageRect.height)
                    .scaleEffect(totalScale, anchor: .topLeading)
                    .offset(x: origin.x, y: origin.y)
            }
        }
        .frame(width: lensRadius * 2, height: lensRadius * 2, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

private struct InlineAnnotationTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let textColor: NSColor
    let alignment: NSTextAlignment
    let preferredContentWidth: CGFloat?
    let preferredContentHeight: CGFloat?
    let onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AutoSizingAnnotationTextField {
        let field = AutoSizingAnnotationTextField(string: text)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.preferredContentWidth = preferredContentWidth
        field.preferredContentHeight = preferredContentHeight
        if let cell = field.cell as? NSTextFieldCell {
            cell.wraps = true
            cell.isScrollable = false
        }
        field.delegate = context.coordinator
        context.coordinator.bind(text: $text, onCommit: onCommit)
        applyStyle(to: field)
        field.invalidateIntrinsicContentSize()
        return field
    }

    func updateNSView(_ nsView: AutoSizingAnnotationTextField, context: Context) {
        context.coordinator.bind(text: $text, onCommit: onCommit)
        applyStyle(to: nsView)
        nsView.preferredContentWidth = preferredContentWidth
        nsView.preferredContentHeight = preferredContentHeight

        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.invalidateIntrinsicContentSize()

        if !context.coordinator.didFocus {
            context.coordinator.didFocus = true
            DispatchQueue.main.async {
                nsView.window?.makeKeyAndOrderFront(nil)
                nsView.window?.makeFirstResponder(nsView)
                context.coordinator.installOutsideClickMonitor(for: nsView)
                if let editor = nsView.currentEditor() as? NSTextView {
                    context.coordinator.applyEditingParagraphStyle(to: editor, alignment: alignment)
                    editor.selectedRange = NSRange(location: nsView.stringValue.count, length: 0)
                }
            }
        } else {
            context.coordinator.installOutsideClickMonitor(for: nsView)
        }
    }

    private func applyStyle(to field: NSTextField) {
        field.font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        field.textColor = textColor
        field.alignment = alignment
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var textBinding: Binding<String> = .constant("")
        var onCommit: () -> Void = {}
        var didFocus = false
        private var outsideClickMonitor: Any?

        func bind(text: Binding<String>, onCommit: @escaping () -> Void) {
            self.textBinding = text
            self.onCommit = onCommit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            textBinding.wrappedValue = field.stringValue
            field.invalidateIntrinsicContentSize()
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            if let editor = field.currentEditor() as? NSTextView {
                applyEditingParagraphStyle(to: editor, alignment: field.alignment)
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            removeOutsideClickMonitor()
            onCommit()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) ||
                commandSelector == #selector(NSResponder.cancelOperation(_:))
            {
                onCommit()
                return true
            }
            return false
        }

        func applyEditingParagraphStyle(to textView: NSTextView, alignment: NSTextAlignment) {
            let style = NSMutableParagraphStyle()
            style.alignment = alignment

            let previousSelection = textView.selectedRange()

            textView.typingAttributes[.paragraphStyle] = style
            let range = NSRange(location: 0, length: textView.string.utf16.count)
            if range.length > 0 {
                textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: range)
                textView.setAlignment(alignment, range: range)
            }
            textView.setSelectedRange(previousSelection)
        }

        func installOutsideClickMonitor(for field: NSTextField) {
            guard outsideClickMonitor == nil else { return }
            outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self, weak field] event in
                guard let self, let field else { return event }
                guard event.window === field.window else {
                    self.onCommit()
                    return event
                }

                let localPoint = field.convert(event.locationInWindow, from: nil)
                if !field.bounds.contains(localPoint) {
                    self.onCommit()
                }
                return event
            }
        }

        func removeOutsideClickMonitor() {
            if let outsideClickMonitor {
                NSEvent.removeMonitor(outsideClickMonitor)
                self.outsideClickMonitor = nil
            }
        }
    }
}

private final class AutoSizingAnnotationTextField: NSTextField {
    var preferredContentWidth: CGFloat?
    var preferredContentHeight: CGFloat?

    override var intrinsicContentSize: NSSize {
        let font = self.font ?? NSFont.systemFont(ofSize: 16, weight: .semibold)
        let text = stringValue.isEmpty ? " " : stringValue

        if let preferredContentWidth {
            let width = max(preferredContentWidth, 8)
            let measured = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            let measuredHeight = ceil(max(measured.height, font.capHeight, 18))
            let height = max(measuredHeight, preferredContentHeight ?? 0)
            return NSSize(width: ceil(width), height: ceil(height))
        }

        let raw = (text as NSString).size(withAttributes: [.font: font])
        return NSSize(width: ceil(max(raw.width, 8)), height: ceil(max(raw.height, 18)))
    }
}

private struct CanvasArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint
    let headLength: CGFloat
    let headAngle: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 0.001)
        guard length > 0.001 else { return path }

        let angle = atan2(dy, dx)
        let left = CGPoint(
            x: end.x - cos(angle - headAngle) * headLength,
            y: end.y - sin(angle - headAngle) * headLength
        )
        let right = CGPoint(
            x: end.x - cos(angle + headAngle) * headLength,
            y: end.y - sin(angle + headAngle) * headLength
        )

        path.move(to: end)
        path.addLine(to: left)
        path.move(to: end)
        path.addLine(to: right)
        return path
    }
}

private struct CurvedCanvasArrowShape: Shape {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint
    let headLength: CGFloat
    let headAngle: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)

        let tangent = CGPoint(x: end.x - control.x, y: end.y - control.y)
        let length = max(hypot(tangent.x, tangent.y), 0.001)
        guard length > 0.001 else { return path }

        let angle = atan2(tangent.y, tangent.x)
        let left = CGPoint(
            x: end.x - cos(angle - headAngle) * headLength,
            y: end.y - sin(angle - headAngle) * headLength
        )
        let right = CGPoint(
            x: end.x - cos(angle + headAngle) * headLength,
            y: end.y - sin(angle + headAngle) * headLength
        )

        path.move(to: end)
        path.addLine(to: left)
        path.move(to: end)
        path.addLine(to: right)
        return path
    }
}

private struct AnnotationVisualStyle {
    let stroke: Color
    let boxFill: Color
    let textForeground: Color
    let textBackground: Color
    let lineWidth: CGFloat
    let boxCornerRadius: CGFloat
    let arrowHeadLength: CGFloat
    let textFontSize: CGFloat
    let textCornerRadius: CGFloat
    let textHorizontalPadding: CGFloat
    let textVerticalPadding: CGFloat

    init(
        preset: EditorState.AnnotationStylePreset,
        customColor: Color,
        boxFillColor: Color,
        boxFillOpacity: Double,
        lineWidth: CGFloat,
        boxCornerRadius: CGFloat,
        isDraft: Bool
    ) {
        let alpha: Double = isDraft ? 0.65 : 1.0

        switch preset {
        case .callout:
            stroke = Color(red: 0.09, green: 0.58, blue: 0.98).opacity(alpha)
            boxFill = Color(red: 0.09, green: 0.58, blue: 0.98).opacity(0.12 * alpha)
            textForeground = .white.opacity(alpha)
            textBackground = Color(red: 0.06, green: 0.28, blue: 0.52).opacity(0.92 * alpha)
        case .subtle:
            stroke = Color.white.opacity(0.88 * alpha)
            boxFill = Color.black.opacity(0.10 * alpha)
            textForeground = .white.opacity(alpha)
            textBackground = Color.black.opacity(0.55 * alpha)
        case .warning:
            stroke = Color(red: 1.0, green: 0.30, blue: 0.28).opacity(alpha)
            boxFill = Color(red: 1.0, green: 0.30, blue: 0.28).opacity(0.13 * alpha)
            textForeground = .white.opacity(alpha)
            textBackground = Color(red: 0.55, green: 0.08, blue: 0.08).opacity(0.95 * alpha)
        case .custom:
            stroke = customColor.opacity(alpha)
            boxFill = boxFillColor.opacity(max(0, min(1, boxFillOpacity)) * alpha)
            textForeground = .white.opacity(alpha)
            textBackground = customColor.opacity(0.92 * alpha)
        }

        self.lineWidth = max(1, lineWidth)
        self.boxCornerRadius = max(0, boxCornerRadius)
        arrowHeadLength = max(10, self.lineWidth * 4.2)
        textFontSize = 16
        textCornerRadius = 9
        textHorizontalPadding = 10
        textVerticalPadding = 6
    }
}

private struct CanvasOuterClipModifier: ViewModifier {
    @ObservedObject var editor: EditorState

    func body(content: Content) -> some View {
        if editor.isAppIconLayout {
            content.clipShape(editor.canvasClipShape)
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: editor.outerCornerRadius, style: .continuous))
        }
    }
}

struct PlaceholderDropView: View {
    @ObservedObject var editor: EditorState

    var body: some View {
        ZStack {
            CanvasBackgroundView(editor: editor)

            RoundedRectangle(cornerRadius: editor.imageCornerRadius)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: editor.imageCornerRadius)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: placeholderShadowColor, radius: editor.shadowRadius, y: placeholderShadowYOffset)
                .padding(editor.canvasPadding)

            VStack(spacing: 10) {
                Image(systemName: AppStrings.Canvas.dropImageSymbol)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(AppStrings.Canvas.dropImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Text(AppStrings.Canvas.dropImageHint)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .clipShape(editor.canvasClipShape)
    }

    private var placeholderShadowColor: Color {
        if editor.shadowRadius <= 0 || editor.shadowOpacity <= 0 {
            return .clear
        }
        return .black.opacity(editor.shadowOpacity)
    }

    private var placeholderShadowYOffset: CGFloat {
        0
    }
}

struct CanvasBackgroundView: View {
    @ObservedObject var editor: EditorState

    var body: some View {
        Rectangle()
            .fill(backgroundFill)
    }

    private var backgroundFill: some ShapeStyle {
        if editor.backgroundStyle == .original {
            return AnyShapeStyle(Color.clear)
        }

        if editor.backgroundStyle == .solid {
            return AnyShapeStyle(editor.solidColor)
        }

        return AnyShapeStyle(editor.backgroundStyle.gradient)
    }
}

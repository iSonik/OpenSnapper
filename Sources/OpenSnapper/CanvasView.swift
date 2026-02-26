import AppKit
import SwiftUI

struct CanvasView: View {
    private enum AnnotationDragMode {
        case move(UUID)
        case resizeBox(UUID, EditorState.AnnotationBoxCorner)
        case resizeArrowStart(UUID)
        case resizeArrowEnd(UUID)
        case resizeArrowBend(UUID)
        case resizeLupeRadius(UUID)
        case resizeText(UUID, EditorState.AnnotationTextHandleSide)
    }

    @EnvironmentObject private var editor: EditorState
    @State private var isCanvasDragging = false
    @State private var annotationDragMode: AnnotationDragMode?
    @State private var pendingTextEditAnnotationID: UUID?
    @State private var annotationDragMoved = false
    @State private var lastScrollCheckpoint = Date.distantPast
    @State private var showsSelectionInspector = false

    var body: some View {
        Group {
            if let image = editor.sourceImage {
                ExportCanvasView(image: image, editor: editor, forExport: false)
            } else {
                PlaceholderDropView(editor: editor)
            }
        }
        .aspectRatio(canvasAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        editor.setCanvasSize(geometry.size)
                    }
                    .onChange(of: geometry.size) { newSize in
                        editor.setCanvasSize(newSize)
                    }
            }
        )
        .overlay {
            if editor.hasImage, editor.editingTextAnnotationID == nil {
                CanvasInteractionCaptureView(
                    onMouseDown: { point in
                        handleCanvasMouseDown(at: point)
                    },
                    onMouseDragged: { point, deltaX, deltaY in
                        handleCanvasMouseDragged(at: point, deltaX: deltaX, deltaY: deltaY)
                    },
                    onMouseUp: { point in
                        handleCanvasMouseUp(at: point)
                    },
                    onMouseMoved: { point in
                        handleCanvasMouseMoved(at: point)
                    },
                    showsEyedropperCursor: editor.isAnnotationCanvasColorPickerActive,
                    onScroll: { event in
                        handleCanvasScroll(event)
                    },
                    onDeleteKey: {
                        editor.deleteSelectedAnnotation()
                    },
                    onEscapeKey: {
                        if editor.editingTextAnnotationID != nil {
                            editor.finishEditingTextAnnotation()
                        } else {
                            editor.hideToMenuBar()
                        }
                    }
                )
            }
        }
        .overlay(alignment: .topLeading) {
            if editor.hasImage,
               editor.annotationTool == .none,
               editor.editingTextAnnotationID == nil,
               annotationDragMode == nil,
               showsSelectionInspector
            {
                CanvasSelectionInspectorOverlay(editor: editor)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: editor.backgroundStyle)
        .animation(.easeInOut(duration: 0.2), value: editor.solidColor)
        .animation(.easeInOut(duration: 0.2), value: editor.canvasPadding)
        .animation(.easeInOut(duration: 0.2), value: editor.outerCornerRadius)
        .animation(.easeInOut(duration: 0.2), value: editor.imageCornerRadius)
        .animation(.easeInOut(duration: 0.2), value: editor.shadowRadius)
        .animation(.easeInOut(duration: 0.2), value: editor.shadowOpacity)
        .animation(.easeInOut(duration: 0.2), value: editor.aspectRatio)
        .animation(.easeInOut(duration: 0.2), value: editor.isAppIconLayout)
        .animation(.easeInOut(duration: 0.2), value: editor.appIconShape)
        .onChange(of: editor.annotationTool) { _ in
            showsSelectionInspector = false
        }
        .onChange(of: editor.selectedAnnotationID) { newValue in
            if newValue == nil {
                showsSelectionInspector = false
            }
        }
        .onChange(of: editor.isAnnotationCanvasColorPickerActive) { isActive in
            if !isActive {
                editor.clearAnnotationCanvasHoverColor()
            }
        }
    }

    private var canvasAspectRatio: CGFloat {
        max(editor.aspectRatio, 0.1)
    }

    private func beginCanvasDragIfNeeded() {
        guard !isCanvasDragging else { return }
        isCanvasDragging = true
        editor.recordUndoCheckpoint()
    }

    private func handleCanvasMouseDown(at point: CGPoint) {
        guard editor.hasImage else { return }
        editor.annotationToolbarPopoverTool = nil

        if editor.isAnnotationCanvasColorPickerActive {
            showsSelectionInspector = false
            _ = editor.sampleAnnotationColorFromCanvas(at: point, in: editor.canvasSize)
            return
        }

        if let hit = editor.annotationHitTarget(at: point, in: editor.canvasSize),
           beginAnnotationHandleInteractionIfNeeded(for: hit)
        {
            return
        }

        switch editor.annotationTool {
        case .none:
            if let hit = editor.annotationHitTarget(at: point, in: editor.canvasSize) {
                editor.selectAnnotation(hit.annotationID)
                showsSelectionInspector = true
                editor.recordUndoCheckpoint()
                pendingTextEditAnnotationID = nil
                annotationDragMoved = false
                switch hit {
                case .body(let id):
                    annotationDragMode = .move(id)
                    if editor.annotations.first(where: { $0.id == id })?.kind == .text {
                        pendingTextEditAnnotationID = id
                    }
                case .boxCorner(let id, let corner):
                    annotationDragMode = .resizeBox(id, corner)
                case .arrowStart(let id):
                    annotationDragMode = .resizeArrowStart(id)
                case .arrowEnd(let id):
                    annotationDragMode = .resizeArrowEnd(id)
                case .arrowBend(let id):
                    annotationDragMode = .resizeArrowBend(id)
                case .lupeRadius(let id):
                    annotationDragMode = .resizeLupeRadius(id)
                case .drawMove(let id):
                    annotationDragMode = .move(id)
                case .textHandle(let id, let side):
                    annotationDragMode = .resizeText(id, side)
                }
                isCanvasDragging = false
                return
            }
            pendingTextEditAnnotationID = nil
            annotationDragMoved = false
            editor.selectAnnotation(nil)
            showsSelectionInspector = false
        case .hand:
            pendingTextEditAnnotationID = nil
            annotationDragMoved = false
            annotationDragMode = nil
            showsSelectionInspector = false
            beginCanvasDragIfNeeded()
        case .text:
            showsSelectionInspector = false
            editor.addTextAnnotation(at: point, in: editor.canvasSize)
        case .draw:
            showsSelectionInspector = false
            editor.selectAnnotation(nil)
            editor.beginFreehandAnnotation(at: point, in: editor.canvasSize)
            editor.updateFreehandAnnotation(at: point, in: editor.canvasSize)
        case .box, .arrow, .lupe:
            showsSelectionInspector = false
            editor.selectAnnotation(nil)
            editor.beginAnnotationDrag(at: point, in: editor.canvasSize)
        }
    }

    private func handleCanvasMouseDragged(at point: CGPoint, deltaX: CGFloat, deltaY: CGFloat) {
        guard editor.hasImage else { return }

        if let annotationDragMode {
            annotationDragMoved = true
            switch annotationDragMode {
            case .move(let id):
                editor.moveAnnotation(id, deltaX: deltaX, deltaY: -deltaY, in: editor.canvasSize)
            case .resizeBox(let id, let corner):
                editor.resizeBoxAnnotation(id, corner: corner, to: point, in: editor.canvasSize)
            case .resizeArrowStart(let id):
                editor.resizeArrowAnnotation(id, movingStart: true, to: point, in: editor.canvasSize)
            case .resizeArrowEnd(let id):
                editor.resizeArrowAnnotation(id, movingStart: false, to: point, in: editor.canvasSize)
            case .resizeArrowBend(let id):
                editor.resizeArrowBendAnnotation(id, to: point, in: editor.canvasSize)
            case .resizeLupeRadius(let id):
                editor.resizeLupeSourceRadiusAnnotation(id, to: point, in: editor.canvasSize)
            case .resizeText(let id, let side):
                editor.resizeTextAnnotationBox(id, handle: side, to: point, in: editor.canvasSize)
            }
            return
        }

        switch editor.annotationTool {
        case .none:
            break
        case .hand:
            updateCanvasDrag(deltaX: deltaX, deltaY: deltaY)
        case .text:
            break
        case .draw:
            editor.updateFreehandAnnotation(at: point, in: editor.canvasSize)
        case .box, .arrow, .lupe:
            editor.updateAnnotationDrag(at: point, in: editor.canvasSize)
        }
    }

    private func handleCanvasMouseMoved(at point: CGPoint) {
        guard editor.hasImage else { return }
        if editor.isAnnotationCanvasColorPickerActive {
            editor.updateAnnotationCanvasHoverColor(at: point, in: editor.canvasSize)
        }
    }

    private func handleCanvasMouseUp(at point: CGPoint) {
        if let currentDragMode = annotationDragMode {
            if editor.annotationTool == .none,
               case .move(let id) = currentDragMode,
               pendingTextEditAnnotationID == id,
               !annotationDragMoved
            {
                _ = editor.beginEditingTextAnnotationIfHit(at: point, in: editor.canvasSize)
            }
            annotationDragMode = nil
            pendingTextEditAnnotationID = nil
            annotationDragMoved = false
            endCanvasDrag()
            return
        }

        switch editor.annotationTool {
        case .none:
            endCanvasDrag()
        case .hand:
            endCanvasDrag()
        case .text:
            break
        case .draw:
            editor.updateFreehandAnnotation(at: point, in: editor.canvasSize)
            editor.commitFreehandAnnotation()
        case .box, .arrow, .lupe:
            editor.updateAnnotationDrag(at: point, in: editor.canvasSize)
            editor.commitAnnotationDrag()
        }
    }

    private func updateCanvasDrag(deltaX: CGFloat, deltaY: CGFloat) {
        guard editor.hasImage else { return }
        beginCanvasDragIfNeeded()
        editor.imageOffsetX = clampedOffset(editor.imageOffsetX + deltaX)
        // AppKit Y grows upward; SwiftUI offset Y grows downward.
        editor.imageOffsetY = clampedOffset(editor.imageOffsetY - deltaY)
    }

    private func endCanvasDrag() {
        isCanvasDragging = false
    }

    private func handleCanvasScroll(_ event: NSEvent) {
        guard editor.hasImage else { return }

        let now = Date()
        if event.phase == .began || now.timeIntervalSince(lastScrollCheckpoint) > 0.45 {
            editor.recordUndoCheckpoint()
            lastScrollCheckpoint = now
        }

        let directionAdjustedDelta = event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? -1 : 1)
        guard abs(directionAdjustedDelta) > 0.001 else { return }

        let zoomFactor = CGFloat(pow(1.002, Double(directionAdjustedDelta * 12)))
        editor.imageScale = clampedZoom(editor.imageScale * zoomFactor)
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        EditorState.clamp(value, to: EditorState.LayoutRanges.zoom)
    }

    private func clampedOffset(_ value: CGFloat) -> CGFloat {
        EditorState.clamp(value, to: EditorState.LayoutRanges.offset)
    }

    private func beginAnnotationHandleInteractionIfNeeded(for hit: EditorState.AnnotationHitTarget) -> Bool {
        switch hit {
        case .body:
            return false
        case .boxCorner(let id, let corner):
            beginAnnotationHandleInteraction(
                annotationID: id,
                dragMode: .resizeBox(id, corner),
                showInspector: editor.annotationTool == .none
            )
        case .arrowStart(let id):
            beginAnnotationHandleInteraction(
                annotationID: id,
                dragMode: .resizeArrowStart(id),
                showInspector: editor.annotationTool == .none
            )
        case .arrowEnd(let id):
            beginAnnotationHandleInteraction(
                annotationID: id,
                dragMode: .resizeArrowEnd(id),
                showInspector: editor.annotationTool == .none
            )
        case .arrowBend(let id):
            beginAnnotationHandleInteraction(
                annotationID: id,
                dragMode: .resizeArrowBend(id),
                showInspector: editor.annotationTool == .none
            )
        case .lupeRadius(let id):
            beginAnnotationHandleInteraction(
                annotationID: id,
                dragMode: .resizeLupeRadius(id),
                showInspector: editor.annotationTool == .none
            )
        case .drawMove(let id):
            beginAnnotationHandleInteraction(
                annotationID: id,
                dragMode: .move(id),
                showInspector: editor.annotationTool == .none
            )
        case .textHandle(let id, let side):
            beginAnnotationHandleInteraction(
                annotationID: id,
                dragMode: .resizeText(id, side),
                showInspector: editor.annotationTool == .none
            )
        }
        return true
    }

    private func beginAnnotationHandleInteraction(
        annotationID: UUID,
        dragMode: AnnotationDragMode,
        showInspector: Bool
    ) {
        editor.selectAnnotation(annotationID)
        showsSelectionInspector = showInspector
        editor.recordUndoCheckpoint()
        pendingTextEditAnnotationID = nil
        annotationDragMoved = false
        annotationDragMode = dragMode
        isCanvasDragging = false
    }
}

private struct CanvasSelectionInspectorOverlay: View {
    @ObservedObject var editor: EditorState

    private let panelWidth: CGFloat = 260

    var body: some View {
        GeometryReader { geometry in
            if let selected = selectedAnnotation {
                let position = clampedPanelOrigin(
                    preferred: preferredPanelOrigin(for: selected, in: geometry.size),
                    canvasSize: geometry.size
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ControlsCustomColorPickerButton(selection: strokeColorBinding(for: selected.id)) {
                            Circle()
                                .fill(effectiveStrokeColor(for: selected.id))
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Text(selected.kind.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.06))
                    )

                    InspectorSlider(
                        label: "Stroke",
                        valueText: String(format: "%.1f", effectiveStrokeWidth(for: selected.id)),
                        value: strokeWidthBinding(for: selected.id),
                        range: 1...12
                    )
                    .environmentObject(editor)

                    if selected.kind == .box {
                        HStack(spacing: 8) {
                            Text("Fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ControlsCustomColorPickerButton(selection: boxFillColorBinding(for: selected.id)) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(effectiveBoxFillColor(for: selected.id))
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.06))
                        )

                        InspectorSlider(
                            label: "Opacity",
                            valueText: "\(Int((effectiveBoxFillOpacity(for: selected.id) * 100).rounded()))%",
                            value: boxFillOpacityBinding(for: selected.id),
                            range: 0...1
                        )
                        .environmentObject(editor)

                        InspectorSlider(
                            label: "Radius",
                            valueText: "\(Int(effectiveBoxCornerRadius(for: selected.id).rounded()))",
                            value: boxCornerRadiusBinding(for: selected.id),
                            range: 0...40
                        )
                        .environmentObject(editor)
                    }

                    if selected.kind == .draw {
                        Toggle("Auto Smooth", isOn: drawAutoSmoothBinding(for: selected.id))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.06))
                            )
                    }

                    if selected.kind == .text {
                        HStack(spacing: 8) {
                            Text("Font")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ControlsCustomColorPickerButton(selection: textFontColorBinding(for: selected.id)) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(effectiveTextFontColor(for: selected.id))
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Spacer(minLength: 0)

                            Text("BG")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ControlsCustomColorPickerButton(selection: textBackgroundColorBinding(for: selected.id)) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(effectiveTextBackgroundColor(for: selected.id))
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.06))
                        )

                        InspectorSlider(
                            label: "Font Size",
                            valueText: "\(Int(effectiveTextFontSize(for: selected.id).rounded()))",
                            value: textFontSizeBinding(for: selected.id),
                            range: 10...40
                        )
                        .environmentObject(editor)

                        HStack(spacing: 6) {
                            ForEach(EditorState.AnnotationTextAlignment.allCases, id: \.self) { alignment in
                                Button {
                                    let current = effectiveTextAlignment(for: selected.id)
                                    guard current != alignment else { return }
                                    editor.recordUndoCheckpoint()
                                    editor.annotationTextAlignmentOverrides[selected.id] = alignment
                                } label: {
                                    Image(systemName: alignment.symbolName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 24, height: 20)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(effectiveTextAlignment(for: selected.id) == alignment ? .accentColor : .gray.opacity(0.45))
                                .help(alignment.title)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.06))
                        )
                    }
                }
                .padding(12)
                .frame(width: panelWidth)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.14))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.10))
                )
                .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
                .position(x: position.x + (panelWidth / 2), y: position.y + (panelHeightEstimate(for: selected.kind) / 2))
                .allowsHitTesting(true)
            }
        }
    }

    private var selectedAnnotation: EditorState.Annotation? {
        guard let id = editor.selectedAnnotationID else { return nil }
        return editor.annotations.first(where: { $0.id == id })
    }

    private func preferredPanelOrigin(for annotation: EditorState.Annotation, in canvasSize: CGSize) -> CGPoint {
        let margin: CGFloat = 12
        let anchor = inspectorAnchorPoint(for: annotation, in: canvasSize)
        return CGPoint(x: anchor.x + 12, y: anchor.y - margin)
    }

    private func clampedPanelOrigin(preferred: CGPoint, canvasSize: CGSize) -> CGPoint {
        let width = panelWidth
        let height = panelHeightEstimate(for: selectedAnnotation?.kind)
        return CGPoint(
            x: min(max(preferred.x, 8), max(8, canvasSize.width - width - 8)),
            y: min(max(preferred.y, 8), max(8, canvasSize.height - height - 8))
        )
    }

    private func panelHeightEstimate(for kind: EditorState.Annotation.Kind?) -> CGFloat {
        switch kind {
        case .box: return 190
        case .text: return 270
        case .draw: return 116
        default: return 96
        }
    }

    private func inspectorAnchorPoint(for annotation: EditorState.Annotation, in canvas: CGSize) -> CGPoint {
        func canvasPoint(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * canvas.width, y: p.y * canvas.height) }

        switch annotation.kind {
        case .box:
            let start = canvasPoint(annotation.start)
            let end = canvasPoint(annotation.end)
            return CGPoint(x: max(start.x, end.x), y: min(start.y, end.y))
        case .arrow:
            let start = canvasPoint(annotation.start)
            let end = canvasPoint(annotation.end)
            if let control = annotation.controlPoint.map(canvasPoint) {
                return CGPoint(
                    x: ((start.x + end.x) * 0.25) + (control.x * 0.5),
                    y: ((start.y + end.y) * 0.25) + (control.y * 0.5)
                )
            }
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        case .lupe:
            return canvasPoint(annotation.end)
        case .draw:
            let points = annotation.points.map(canvasPoint)
            guard let first = points.first else { return canvasPoint(annotation.start) }
            var minX = first.x
            var minY = first.y
            var maxX = first.x
            for point in points.dropFirst() {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
            }
            return CGPoint(x: maxX, y: minY)
        case .text:
            return canvasPoint(annotation.start)
        }
    }

    private func effectiveStrokeColor(for id: UUID) -> Color {
        editor.annotationColorOverrides[id] ?? editor.annotationCustomColor
    }

    private func effectiveStrokeWidth(for id: UUID) -> CGFloat {
        editor.annotationStrokeWidthOverrides[id] ?? editor.annotationStrokeWidth
    }

    private func effectiveBoxFillColor(for id: UUID) -> Color {
        editor.annotationBoxFillColorOverrides[id] ?? editor.annotationBoxFillColor
    }

    private func effectiveBoxFillOpacity(for id: UUID) -> Double {
        editor.annotationBoxFillOpacityOverrides[id] ?? editor.annotationBoxFillOpacity
    }

    private func effectiveBoxCornerRadius(for id: UUID) -> CGFloat {
        editor.annotationBoxCornerRadiusOverrides[id] ?? editor.annotationBoxCornerRadius
    }

    private func effectiveTextFontColor(for id: UUID) -> Color {
        if let override = editor.annotationTextFontColorOverrides[id] {
            return override
        }
        return editor.annotationTextDefaultFontColor
    }

    private func effectiveTextBackgroundColor(for id: UUID) -> Color {
        if let override = editor.annotationTextBackgroundColorOverrides[id] {
            return override
        }
        return editor.annotationTextDefaultBackgroundColor
    }

    private func effectiveTextFontSize(for id: UUID) -> CGFloat {
        editor.annotationTextFontSizeOverrides[id] ?? editor.annotationTextDefaultFontSize
    }

    private func effectiveTextAlignment(for id: UUID) -> EditorState.AnnotationTextAlignment {
        editor.annotationTextAlignmentOverrides[id] ?? editor.annotationTextDefaultAlignment
    }

    private func strokeColorBinding(for id: UUID) -> Binding<Color> {
        Binding(
            get: { effectiveStrokeColor(for: id) },
            set: { newValue in
                guard effectiveStrokeColor(for: id) != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationColorOverrides[id] = newValue
            }
        )
    }

    private func strokeWidthBinding(for id: UUID) -> Binding<CGFloat> {
        Binding(
            get: { effectiveStrokeWidth(for: id) },
            set: { editor.annotationStrokeWidthOverrides[id] = $0 }
        )
    }

    private func boxFillColorBinding(for id: UUID) -> Binding<Color> {
        Binding(
            get: { effectiveBoxFillColor(for: id) },
            set: { newValue in
                guard effectiveBoxFillColor(for: id) != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationBoxFillColorOverrides[id] = newValue
            }
        )
    }

    private func boxFillOpacityBinding(for id: UUID) -> Binding<CGFloat> {
        Binding(
            get: { CGFloat(effectiveBoxFillOpacity(for: id)) },
            set: { editor.annotationBoxFillOpacityOverrides[id] = Double($0) }
        )
    }

    private func boxCornerRadiusBinding(for id: UUID) -> Binding<CGFloat> {
        Binding(
            get: { effectiveBoxCornerRadius(for: id) },
            set: { editor.annotationBoxCornerRadiusOverrides[id] = $0 }
        )
    }

    private func drawAutoSmoothBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { editor.annotationDrawAutoSmoothOverrides[id] ?? editor.annotationDrawAutoSmooth },
            set: { newValue in
                let current = editor.annotationDrawAutoSmoothOverrides[id] ?? editor.annotationDrawAutoSmooth
                guard current != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationDrawAutoSmoothOverrides[id] = newValue
            }
        )
    }

    private func textFontColorBinding(for id: UUID) -> Binding<Color> {
        Binding(
            get: { effectiveTextFontColor(for: id) },
            set: { newValue in
                guard effectiveTextFontColor(for: id) != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationTextFontColorOverrides[id] = newValue
            }
        )
    }

    private func textBackgroundColorBinding(for id: UUID) -> Binding<Color> {
        Binding(
            get: { effectiveTextBackgroundColor(for: id) },
            set: { newValue in
                guard effectiveTextBackgroundColor(for: id) != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationTextBackgroundColorOverrides[id] = newValue
            }
        )
    }

    private func textFontSizeBinding(for id: UUID) -> Binding<CGFloat> {
        Binding(
            get: { effectiveTextFontSize(for: id) },
            set: { editor.annotationTextFontSizeOverrides[id] = $0 }
        )
    }
}

private struct InspectorSlider: View {
    @EnvironmentObject private var editor: EditorState

    let label: String
    let valueText: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, onEditingChanged: { editing in
                if editing {
                    editor.recordUndoCheckpoint()
                }
            })
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06))
        )
    }
}

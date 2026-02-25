import AppKit
import SwiftUI

struct CanvasView: View {
    private enum AnnotationDragMode {
        case move(UUID)
        case resizeBox(UUID, EditorState.AnnotationBoxCorner)
        case resizeArrowStart(UUID)
        case resizeArrowEnd(UUID)
        case resizeText(UUID, EditorState.AnnotationTextHandleSide)
    }

    @EnvironmentObject private var editor: EditorState
    @State private var isCanvasDragging = false
    @State private var annotationDragMode: AnnotationDragMode?
    @State private var pendingTextEditAnnotationID: UUID?
    @State private var annotationDragMoved = false
    @State private var lastScrollCheckpoint = Date.distantPast

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
        .animation(.easeInOut(duration: 0.2), value: editor.backgroundStyle)
        .animation(.easeInOut(duration: 0.2), value: editor.solidColor)
        .animation(.easeInOut(duration: 0.2), value: editor.canvasPadding)
        .animation(.easeInOut(duration: 0.2), value: editor.outerCornerRadius)
        .animation(.easeInOut(duration: 0.2), value: editor.imageCornerRadius)
        .animation(.easeInOut(duration: 0.2), value: editor.shadowRadius)
        .animation(.easeInOut(duration: 0.2), value: editor.shadowOpacity)
        .animation(.easeInOut(duration: 0.2), value: editor.imageScale)
        .animation(.easeInOut(duration: 0.2), value: editor.imageOffsetX)
        .animation(.easeInOut(duration: 0.2), value: editor.imageOffsetY)
        .animation(.easeInOut(duration: 0.2), value: editor.aspectRatio)
        .animation(.easeInOut(duration: 0.2), value: editor.isAppIconLayout)
        .animation(.easeInOut(duration: 0.2), value: editor.appIconShape)
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

        switch editor.annotationTool {
        case .none:
            if let hit = editor.annotationHitTarget(at: point, in: editor.canvasSize) {
                editor.selectAnnotation(hit.annotationID)
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
                case .textHandle(let id, let side):
                    annotationDragMode = .resizeText(id, side)
                }
                isCanvasDragging = false
                return
            }
            pendingTextEditAnnotationID = nil
            annotationDragMoved = false
            editor.selectAnnotation(nil)
            beginCanvasDragIfNeeded()
        case .text:
            editor.addTextAnnotation(at: point, in: editor.canvasSize)
        case .box, .arrow:
            editor.selectAnnotation(nil)
            editor.beginAnnotationDrag(at: point, in: editor.canvasSize)
        }
    }

    private func handleCanvasMouseDragged(at point: CGPoint, deltaX: CGFloat, deltaY: CGFloat) {
        guard editor.hasImage else { return }

        switch editor.annotationTool {
        case .none:
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
                case .resizeText(let id, let side):
                    editor.resizeTextAnnotationBox(id, handle: side, to: point, in: editor.canvasSize)
                }
            } else {
                updateCanvasDrag(deltaX: deltaX, deltaY: deltaY)
            }
        case .text:
            break
        case .box, .arrow:
            editor.updateAnnotationDrag(at: point, in: editor.canvasSize)
        }
    }

    private func handleCanvasMouseUp(at point: CGPoint) {
        switch editor.annotationTool {
        case .none:
            if case .move(let id)? = annotationDragMode,
               pendingTextEditAnnotationID == id,
               !annotationDragMoved
            {
                _ = editor.beginEditingTextAnnotationIfHit(at: point, in: editor.canvasSize)
            }
            annotationDragMode = nil
            pendingTextEditAnnotationID = nil
            annotationDragMoved = false
            endCanvasDrag()
        case .text:
            break
        case .box, .arrow:
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
}

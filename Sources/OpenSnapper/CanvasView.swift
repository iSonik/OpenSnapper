import AppKit
import SwiftUI

struct CanvasView: View {
    @EnvironmentObject private var editor: EditorState
    @State private var isCanvasDragging = false
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
            if editor.hasImage {
                CanvasInteractionCaptureView(
                    onDragBegan: { beginCanvasDragIfNeeded() },
                    onDragDelta: { deltaX, deltaY in
                        updateCanvasDrag(deltaX: deltaX, deltaY: deltaY)
                    },
                    onDragEnded: { endCanvasDrag() },
                    onScroll: { event in
                        handleCanvasScroll(event)
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

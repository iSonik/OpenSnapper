import AppKit
import SwiftUI

struct CanvasInteractionCaptureView: NSViewRepresentable {
    let onDragBegan: () -> Void
    let onDragDelta: (CGFloat, CGFloat) -> Void
    let onDragEnded: () -> Void
    let onScroll: (NSEvent) -> Void

    func makeNSView(context: Context) -> CanvasInteractionNSView {
        let view = CanvasInteractionNSView()
        view.onDragBegan = onDragBegan
        view.onDragDelta = onDragDelta
        view.onDragEnded = onDragEnded
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: CanvasInteractionNSView, context: Context) {
        nsView.onDragBegan = onDragBegan
        nsView.onDragDelta = onDragDelta
        nsView.onDragEnded = onDragEnded
        nsView.onScroll = onScroll
    }
}

final class CanvasInteractionNSView: NSView {
    var onDragBegan: (() -> Void)?
    var onDragDelta: ((CGFloat, CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    var onScroll: ((NSEvent) -> Void)?

    private var isDragging = false
    private var lastMouseLocation: NSPoint = .zero

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isDragging = true
        lastMouseLocation = convert(event.locationInWindow, from: nil)
        onDragBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let current = convert(event.locationInWindow, from: nil)
        let deltaX = current.x - lastMouseLocation.x
        let deltaY = current.y - lastMouseLocation.y
        lastMouseLocation = current
        onDragDelta?(deltaX, deltaY)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        onDragEnded?()
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
    }
}

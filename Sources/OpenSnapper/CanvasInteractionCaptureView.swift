import AppKit
import SwiftUI

struct CanvasInteractionCaptureView: NSViewRepresentable {
    let onMouseDown: (CGPoint) -> Void
    let onMouseDragged: (CGPoint, CGFloat, CGFloat) -> Void
    let onMouseUp: (CGPoint) -> Void
    let onScroll: (NSEvent) -> Void
    let onDeleteKey: () -> Void
    let onEscapeKey: () -> Void

    func makeNSView(context: Context) -> CanvasInteractionNSView {
        let view = CanvasInteractionNSView()
        view.onMouseDown = onMouseDown
        view.onMouseDragged = onMouseDragged
        view.onMouseUp = onMouseUp
        view.onScroll = onScroll
        view.onDeleteKey = onDeleteKey
        view.onEscapeKey = onEscapeKey
        return view
    }

    func updateNSView(_ nsView: CanvasInteractionNSView, context: Context) {
        nsView.onMouseDown = onMouseDown
        nsView.onMouseDragged = onMouseDragged
        nsView.onMouseUp = onMouseUp
        nsView.onScroll = onScroll
        nsView.onDeleteKey = onDeleteKey
        nsView.onEscapeKey = onEscapeKey
    }
}

final class CanvasInteractionNSView: NSView {
    var onMouseDown: ((CGPoint) -> Void)?
    var onMouseDragged: ((CGPoint, CGFloat, CGFloat) -> Void)?
    var onMouseUp: ((CGPoint) -> Void)?
    var onScroll: ((NSEvent) -> Void)?
    var onDeleteKey: (() -> Void)?
    var onEscapeKey: (() -> Void)?

    private var isDragging = false
    private var lastMouseLocation: NSPoint = .zero

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        isDragging = true
        lastMouseLocation = convert(event.locationInWindow, from: nil)
        onMouseDown?(topLeftPoint(from: lastMouseLocation))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let current = convert(event.locationInWindow, from: nil)
        let deltaX = current.x - lastMouseLocation.x
        let deltaY = current.y - lastMouseLocation.y
        lastMouseLocation = current
        onMouseDragged?(topLeftPoint(from: current), deltaX, deltaY)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        let point = convert(event.locationInWindow, from: nil)
        onMouseUp?(topLeftPoint(from: point))
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117: // delete / forward delete
            onDeleteKey?()
        case 53: // escape
            onEscapeKey?()
        default:
            super.keyDown(with: event)
        }
    }

    private func topLeftPoint(from point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: bounds.height - point.y)
    }
}

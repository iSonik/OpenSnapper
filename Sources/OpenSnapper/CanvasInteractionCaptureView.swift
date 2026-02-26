import AppKit
import SwiftUI

struct CanvasInteractionCaptureView: NSViewRepresentable {
    let onMouseDown: (CGPoint) -> Void
    let onMouseDragged: (CGPoint, CGFloat, CGFloat) -> Void
    let onMouseUp: (CGPoint) -> Void
    let onMouseMoved: (CGPoint) -> Void
    let showsEyedropperCursor: Bool
    let onScroll: (NSEvent) -> Void
    let onDeleteKey: () -> Void
    let onEscapeKey: () -> Void

    func makeNSView(context: Context) -> CanvasInteractionNSView {
        let view = CanvasInteractionNSView()
        view.onMouseDown = onMouseDown
        view.onMouseDragged = onMouseDragged
        view.onMouseUp = onMouseUp
        view.onMouseMoved = onMouseMoved
        view.showsEyedropperCursor = showsEyedropperCursor
        view.onScroll = onScroll
        view.onDeleteKey = onDeleteKey
        view.onEscapeKey = onEscapeKey
        return view
    }

    func updateNSView(_ nsView: CanvasInteractionNSView, context: Context) {
        nsView.onMouseDown = onMouseDown
        nsView.onMouseDragged = onMouseDragged
        nsView.onMouseUp = onMouseUp
        nsView.onMouseMoved = onMouseMoved
        nsView.showsEyedropperCursor = showsEyedropperCursor
        nsView.onScroll = onScroll
        nsView.onDeleteKey = onDeleteKey
        nsView.onEscapeKey = onEscapeKey
    }
}

final class CanvasInteractionNSView: NSView {
    var onMouseDown: ((CGPoint) -> Void)?
    var onMouseDragged: ((CGPoint, CGFloat, CGFloat) -> Void)?
    var onMouseUp: ((CGPoint) -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?
    var showsEyedropperCursor = false {
        didSet {
            guard oldValue != showsEyedropperCursor else { return }
            window?.invalidateCursorRects(for: self)
            applyCurrentCursor()
        }
    }
    var onScroll: ((NSEvent) -> Void)?
    var onDeleteKey: (() -> Void)?
    var onEscapeKey: (() -> Void)?

    private var isDragging = false
    private var lastMouseLocation: NSPoint = .zero
    private var trackingAreaRef: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        applyCurrentCursor()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: showsEyedropperCursor ? Self.eyedropperCursor : .arrow)
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

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        applyCurrentCursor()
        onMouseMoved?(topLeftPoint(from: point))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        applyCurrentCursor()
    }

    override func cursorUpdate(with event: NSEvent) {
        applyCurrentCursor()
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

    private func applyCurrentCursor() {
        (showsEyedropperCursor ? Self.eyedropperCursor : NSCursor.arrow).set()
    }

    private static let eyedropperCursor: NSCursor = {
        guard let symbol = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: nil) else {
            return .crosshair
        }

        let configured = symbol.withSymbolConfiguration(.init(pointSize: 16, weight: .medium)) ?? symbol
        let canvasSize = NSSize(width: 24, height: 24)
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: canvasSize)
        NSColor.clear.setFill()
        rect.fill()

        configured.draw(
            in: NSRect(x: 3, y: 3, width: 18, height: 18),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        // Approximate the tip of the eyedropper glyph.
        return NSCursor(image: image, hotSpot: NSPoint(x: 5, y: 5))
    }()
}

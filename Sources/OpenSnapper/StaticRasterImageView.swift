import AppKit
import SwiftUI

struct StaticRasterImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> StaticRasterNSView {
        let view = StaticRasterNSView()
        view.setImage(image)
        return view
    }

    func updateNSView(_ nsView: StaticRasterNSView, context: Context) {
        nsView.setImage(image)
    }
}

final class StaticRasterNSView: NSView {
    private var cachedImageHash: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .trilinear
        layer?.minificationFilter = .trilinear
        layer?.isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: NSImage) {
        let newHash = image.hashValue
        guard cachedImageHash != newHash else { return }
        cachedImageHash = newHash
        layer?.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

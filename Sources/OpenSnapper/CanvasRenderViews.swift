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

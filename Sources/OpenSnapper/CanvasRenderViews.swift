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
                    (editor.annotationTool == .box || editor.annotationTool == .arrow)
                {
                    annotationView(
                        EditorState.Annotation(
                            id: UUID(),
                            kind: editor.annotationTool == .arrow ? .arrow : .box,
                            stylePreset: editor.annotationStylePreset,
                            start: start,
                            end: end,
                            text: nil,
                            textBoxWidth: nil,
                            textBoxHeight: nil
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
            customColor: editor.annotationCustomColor,
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
            ZStack {
                CanvasArrowShape(
                    start: start,
                    end: end,
                    headLength: style.arrowHeadLength,
                    headAngle: .pi / 7
                )
                .stroke(style.stroke, style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round))

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
                }
            }

        case .text:
            let point = canvasPoint(annotation.start, in: canvasSize)
            let selected = !forExport && editor.selectedAnnotationID == annotation.id
            let contentWidth = textContentWidth(for: annotation, style: style, in: canvasSize)
            let contentHeight = textContentHeight(for: annotation, style: style, in: canvasSize)
            if !forExport, editor.editingTextAnnotationID == annotation.id {
                InlineAnnotationTextEditor(
                    text: textBinding(for: annotation.id),
                    fontSize: style.textFontSize,
                    textColor: NSColor(style.textForeground),
                    preferredContentWidth: contentWidth,
                    preferredContentHeight: contentHeight,
                    onCommit: {
                        editor.finishEditingTextAnnotation()
                    }
                )
                    .frame(width: contentWidth, alignment: .center)
                    .frame(height: contentHeight, alignment: .center)
                    .padding(.horizontal, style.textHorizontalPadding)
                    .padding(.vertical, style.textVerticalPadding)
                    .background(style.textBackground, in: RoundedRectangle(cornerRadius: style.textCornerRadius, style: .continuous))
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
                    .font(.system(size: style.textFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(style.textForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(width: contentWidth, alignment: .center)
                    .frame(minHeight: contentHeight, alignment: .center)
                    .padding(.horizontal, style.textHorizontalPadding)
                    .padding(.vertical, style.textVerticalPadding)
                    .background(style.textBackground, in: RoundedRectangle(cornerRadius: style.textCornerRadius, style: .continuous))
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
        let font = NSFont.systemFont(ofSize: style.textFontSize, weight: .semibold)

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
}

private struct InlineAnnotationTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let textColor: NSColor
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
                    context.coordinator.applyCenteredEditingParagraphStyle(to: editor)
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
        field.alignment = .center
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
                applyCenteredEditingParagraphStyle(to: editor)
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

        func applyCenteredEditingParagraphStyle(to textView: NSTextView) {
            let style = NSMutableParagraphStyle()
            style.alignment = .center

            let previousSelection = textView.selectedRange()

            textView.typingAttributes[.paragraphStyle] = style
            let range = NSRange(location: 0, length: textView.string.utf16.count)
            if range.length > 0 {
                textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: range)
                textView.setAlignment(.center, range: range)
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

    init(preset: EditorState.AnnotationStylePreset, customColor: Color, isDraft: Bool) {
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
            boxFill = customColor.opacity(0.14 * alpha)
            textForeground = .white.opacity(alpha)
            textBackground = customColor.opacity(0.92 * alpha)
        }

        lineWidth = 3
        boxCornerRadius = 10
        arrowHeadLength = 14
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

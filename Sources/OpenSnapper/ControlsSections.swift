import AppKit
import SwiftUI

private struct ControlsFullWidthButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

private struct ControlsDragExportButton: View {
    @EnvironmentObject private var editor: EditorState
    let title: String

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 0)
            Image(systemName: "hand.draw")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        )
        .opacity(editor.hasImage ? 1 : 0.5)
        .contentShape(Rectangle())
        .onDrag {
            editor.dragProviderForSavedExportFile() ?? NSItemProvider()
        }
        .allowsHitTesting(editor.hasImage)
    }
}

struct ControlsCustomColorPickerButton<Label: View>: View {
    @Binding var selection: Color
    var onOpen: () -> Void = {}
    @ViewBuilder let label: () -> Label
    @State private var isPresented = false

    var body: some View {
        Button {
            onOpen()
            isPresented.toggle()
        } label: {
            label()
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ControlsCustomColorPickerPopover(selection: $selection)
        }
    }
}

private struct ControlsCustomColorPickerRow: View {
    let title: String
    @Binding var selection: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer(minLength: 0)

            ControlsCustomColorPickerButton(selection: $selection) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(selection)
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        )
                    Text(ControlsCustomColorPickerPopover.hexString(from: selection))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct ControlsCustomColorPickerPopover: View {
    struct RGB: Equatable {
        var red: Double
        var green: Double
        var blue: Double
    }

    @Binding var selection: Color
    @State private var rgb: RGB

    private static let swatches: [Color] = [
        Color(red: 0.96, green: 0.28, blue: 0.25),
        Color(red: 0.99, green: 0.55, blue: 0.18),
        Color(red: 0.99, green: 0.84, blue: 0.20),
        Color(red: 0.56, green: 0.84, blue: 0.28),
        Color(red: 0.20, green: 0.78, blue: 0.35),
        Color(red: 0.11, green: 0.61, blue: 0.97),
        Color(red: 0.29, green: 0.46, blue: 0.96),
        Color(red: 0.48, green: 0.33, blue: 0.92),
        Color(red: 0.87, green: 0.29, blue: 0.74),
        Color(red: 0.93, green: 0.33, blue: 0.49),
        Color(red: 0.10, green: 0.10, blue: 0.12),
        Color(red: 0.22, green: 0.22, blue: 0.26),
        Color(red: 0.38, green: 0.38, blue: 0.44),
        Color(red: 0.56, green: 0.56, blue: 0.62),
        Color(red: 0.76, green: 0.76, blue: 0.82),
        Color(red: 0.96, green: 0.96, blue: 0.98)
    ]

    init(selection: Binding<Color>) {
        _selection = selection
        _rgb = State(initialValue: Self.rgb(from: selection.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selection)
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Color")
                        .font(.callout.weight(.semibold))
                    Text(Self.hexString(from: selection))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 8), spacing: 8) {
                ForEach(Array(Self.swatches.enumerated()), id: \.offset) { _, swatch in
                    Button {
                        apply(color: swatch)
                    } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(swatch)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        Self.hexString(from: swatch) == Self.hexString(from: selection)
                                        ? Color.white.opacity(0.95)
                                        : Color.white.opacity(0.25),
                                        lineWidth: Self.hexString(from: swatch) == Self.hexString(from: selection) ? 2 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            sliderRow("R", value: componentBinding(\.red), tint: .red)
            sliderRow("G", value: componentBinding(\.green), tint: .green)
            sliderRow("B", value: componentBinding(\.blue), tint: .blue)
        }
        .padding(14)
        .frame(width: 270)
        .background(Color.clear)
        .onAppear {
            rgb = Self.rgb(from: selection)
        }
        .onChange(of: rgb) { newValue in
            selection = Color(red: newValue.red, green: newValue.green, blue: newValue.blue)
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)

            Slider(value: value, in: 0...1)
                .tint(tint)

            Text("\(Int((value.wrappedValue * 255).rounded()))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }

    private func componentBinding(_ keyPath: WritableKeyPath<RGB, Double>) -> Binding<Double> {
        Binding(
            get: { rgb[keyPath: keyPath] },
            set: { rgb[keyPath: keyPath] = $0 }
        )
    }

    private func apply(color: Color) {
        rgb = Self.rgb(from: color)
        selection = color
    }

    static func hexString(from color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return String(
            format: "#%02X%02X%02X",
            Int(round(nsColor.redComponent * 255)),
            Int(round(nsColor.greenComponent * 255)),
            Int(round(nsColor.blueComponent * 255))
        )
    }

    private static func rgb(from color: Color) -> RGB {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return RGB(
            red: nsColor.redComponent,
            green: nsColor.greenComponent,
            blue: nsColor.blueComponent
        )
    }
}

private struct ControlsSectionContent<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ControlsSliderRow: View {
    @EnvironmentObject private var editor: EditorState

    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let valueText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(valueText ?? "\(Int(value))")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range, onEditingChanged: { editing in
                if editing {
                    editor.recordUndoCheckpoint()
                }
            })
        }
    }
}

private struct ControlsShadowOpacityRow: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(AppStrings.Controls.shadowOpacity): \(Int(editor.shadowOpacity * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $editor.shadowOpacity, in: EditorState.LayoutRanges.shadowOpacity, onEditingChanged: { editing in
                if editing {
                    editor.recordUndoCheckpoint()
                }
            })
        }
    }
}

private struct ControlsRatioButton: View {
    @EnvironmentObject private var editor: EditorState

    let label: String
    let ratio: CGFloat
    let isSelected: Bool

    var body: some View {
        Button {
            editor.setAspectRatio(ratio)
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? .accentColor : .gray.opacity(0.45))
    }
}

private struct ControlsAppIconRatioButton: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        Button {
            editor.applyAppIconLayoutPreset()
        } label: {
            Text(AppStrings.Controls.appIcon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(editor.isAppIconLayout ? .accentColor : .gray.opacity(0.45))
    }
}

private struct ControlsCustomLayoutPresetButton: View {
    @EnvironmentObject private var editor: EditorState
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(AppStrings.Controls.customPreset)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(editor.isCustomLayoutMode ? .accentColor : .gray.opacity(0.45))
    }
}

private struct CustomLayoutDraft: Equatable {
    var aspectWidthText: String
    var aspectHeightText: String
    var outerCornerRadius: CGFloat

    init(
        aspectWidthText: String = "4",
        aspectHeightText: String = "5",
        outerCornerRadius: CGFloat = EditorState.LayoutDefaults.CustomPreset.outerCornerRadius
    ) {
        self.aspectWidthText = aspectWidthText
        self.aspectHeightText = aspectHeightText
        self.outerCornerRadius = outerCornerRadius
    }

    @MainActor
    init(editor: EditorState) {
        let ratio = max(editor.aspectRatio, 0.1)
        let ratioPair = Self.ratioPair(for: ratio, selectedID: editor.selectedStandardAspectRatioID)
        self.init(
            aspectWidthText: ratioPair.width,
            aspectHeightText: ratioPair.height,
            outerCornerRadius: editor.outerCornerRadius
        )
    }

    var parsedAspectRatio: CGFloat? {
        guard
            let width = Double(aspectWidthText.replacingOccurrences(of: ",", with: ".")),
            let height = Double(aspectHeightText.replacingOccurrences(of: ",", with: ".")),
            width > 0,
            height > 0
        else {
            return nil
        }
        return CGFloat(width / height)
    }

    var isValid: Bool { parsedAspectRatio != nil }

    private static func ratioPair(for ratio: CGFloat, selectedID: String?) -> (width: String, height: String) {
        if let selectedID,
           let separator = selectedID.firstIndex(of: ":")
        {
            return (
                width: String(selectedID[..<separator]),
                height: String(selectedID[selectedID.index(after: separator)...])
            )
        }

        if abs(ratio - 1.0) < 0.0005 {
            return ("1", "1")
        }
        if ratio >= 1 {
            return (String(format: "%.2f", ratio), "1")
        }
        return ("1", String(format: "%.2f", 1 / ratio))
    }
}

private struct ControlsCustomLayoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var draft: CustomLayoutDraft
    let apply: (CustomLayoutDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom Layout")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                Text("Aspect Ratio")
                    .frame(width: 92, alignment: .leading)
                TextField("Width", text: $draft.aspectWidthText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text(":")
                    .foregroundStyle(.secondary)
                TextField("Height", text: $draft.aspectHeightText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Spacer(minLength: 0)
                if let ratio = draft.parsedAspectRatio {
                    Text(String(format: "%.3f", ratio))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                quickRatioButton("1:1", w: "1", h: "1")
                quickRatioButton("4:5", w: "4", h: "5")
                quickRatioButton("9:16", w: "9", h: "16")
                quickRatioButton("16:9", w: "16", h: "9")
                quickRatioButton("3:2", w: "3", h: "2")
            }

            Divider()

            sliderRow("Outer Radius", value: $draft.outerCornerRadius, range: EditorState.LayoutRanges.outerCornerRadius, valueText: "\(Int(draft.outerCornerRadius.rounded()))")

            HStack {
                Spacer(minLength: 0)
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    apply(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private func quickRatioButton(_ title: String, w: String, h: String) -> some View {
        Button(title) {
            draft.aspectWidthText = w
            draft.aspectHeightText = h
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func sliderRow(
        _ label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer(minLength: 0)
                Text(valueText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

struct ControlsImageSection: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        GroupBox(AppStrings.Controls.imageGroup) {
            ControlsSectionContent(spacing: 10) {
                ControlsFullWidthButton(title: AppStrings.Controls.selectArea) { editor.captureScreenshot() }
                    .disabled(!editor.hasScreenCaptureAccess)
                ControlsFullWidthButton(title: AppStrings.Controls.wholeScreen) { editor.captureWholeScreen() }
                    .disabled(!editor.hasScreenCaptureAccess)
                ControlsFullWidthButton(title: AppStrings.Controls.selectImage) { editor.openImagePanel() }
                ControlsFullWidthButton(title: AppStrings.Controls.save) { editor.exportPNG() }
                    .disabled(!editor.hasImage)
                ControlsFullWidthButton(title: AppStrings.Controls.openInFinder) { editor.saveAndRevealExportInFinder() }
                    .disabled(!editor.hasImage)
                ControlsDragExportButton(title: AppStrings.Controls.dragSavedFile)
            }
        }
    }
}

struct ControlsToolkitSection: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        GroupBox(AppStrings.Controls.toolkitGroup) {
            ControlsSectionContent {
                ControlsFullWidthButton(title: editor.backgroundRemovalMode == .isolateSubjectAI ? AppStrings.Controls.isolating : AppStrings.Controls.isolateSubject) {
                    editor.isolateSubjectWithAI()
                }
                .disabled(!editor.hasImage || editor.isRemovingBackground)

                ControlsFullWidthButton(title: editor.backgroundRemovalMode == .solidColor ? AppStrings.Controls.removing : AppStrings.Controls.removeSolidBackground) {
                    editor.removeSolidBackground()
                }
                .disabled(!editor.hasImage || editor.isRemovingBackground)
            }
        }
    }
}

struct ControlsAnnotationsTopBar: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(EditorState.AnnotationTool.allCases) { tool in
                    Button {
                        let wasSameSelection = editor.annotationTool == tool
                        editor.setAnnotationTool(tool)
                        if tool.supportsToolkitPopover {
                            if wasSameSelection {
                                editor.annotationToolbarPopoverTool = (editor.annotationToolbarPopoverTool == tool) ? nil : tool
                            } else {
                                // First click selects the tool; second click opens its toolkit.
                                editor.annotationToolbarPopoverTool = nil
                            }
                        } else {
                            editor.annotationToolbarPopoverTool = nil
                        }
                    } label: {
                        Image(systemName: tool.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(editor.annotationTool == tool ? .accentColor : .gray.opacity(0.45))
                    .help(tool.title)
                    .popover(
                        isPresented: toolkitPopoverBinding(for: tool),
                        attachmentAnchor: .point(.bottom),
                        arrowEdge: .bottom
                    ) {
                        ControlsAnnotationToolPopover(tool: tool)
                            .environmentObject(editor)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                editor.pickAnnotationColorFromScreenKeepingAppVisible()
            } label: {
                Image(systemName: "eyedropper")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 22)
            }
            .buttonStyle(.borderedProminent)
            .tint(editor.isColorPickerActive ? .accentColor : .gray.opacity(0.45))
            .disabled(!editor.hasImage)
            .help("Pick color from image")

            ControlsCustomColorPickerButton(
                selection: $editor.annotationCustomColor,
                onOpen: { editor.annotationStylePreset = .custom }
            ) {
                Circle()
                    .fill(editor.annotationCustomColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1))
                    .frame(width: 26, height: 22)
            }
            .buttonStyle(.plain)
            .help("Annotation color")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .onAppear {
            if editor.annotationStylePreset != .custom {
                editor.annotationStylePreset = .custom
            }
        }
        .onChange(of: editor.annotationTool) { newTool in
            if !newTool.supportsToolkitPopover {
                editor.annotationToolbarPopoverTool = nil
            }
        }
    }

    private func toolkitPopoverBinding(for tool: EditorState.AnnotationTool) -> Binding<Bool> {
        Binding(
            get: { editor.annotationToolbarPopoverTool == tool && tool.supportsToolkitPopover },
            set: { isPresented in
                if isPresented, tool.supportsToolkitPopover {
                    editor.annotationToolbarPopoverTool = tool
                } else if editor.annotationToolbarPopoverTool == tool {
                    editor.annotationToolbarPopoverTool = nil
                }
            }
        )
    }
}

private struct ControlsAnnotationToolPopover: View {
    @EnvironmentObject private var editor: EditorState
    let tool: EditorState.AnnotationTool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tool.supportsStrokeControl {
                AnnotationToolkitMiniSlider(
                    label: "Stroke",
                    valueText: String(format: "%.1f", editor.annotationStrokeWidth),
                    value: $editor.annotationStrokeWidth,
                    range: 1...12,
                    width: 220
                )
                .environmentObject(editor)
            }

            if tool == .box {
                ControlsCustomColorPickerRow(title: "Fill", selection: $editor.annotationBoxFillColor)

                AnnotationToolkitMiniSlider(
                    label: "Opacity",
                    valueText: "\(Int((editor.annotationBoxFillOpacity * 100).rounded()))%",
                    value: Binding(
                        get: { CGFloat(editor.annotationBoxFillOpacity) },
                        set: { editor.annotationBoxFillOpacity = Double($0) }
                    ),
                    range: 0...1,
                    width: 220
                )
                .environmentObject(editor)

                AnnotationToolkitMiniSlider(
                    label: "Radius",
                    valueText: "\(Int(editor.annotationBoxCornerRadius.rounded()))",
                    value: $editor.annotationBoxCornerRadius,
                    range: 0...40,
                    width: 220
                )
                .environmentObject(editor)
            }

            if tool == .draw {
                Toggle("Auto Smooth", isOn: drawAutoSmoothBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if tool == .text {
                ControlsCustomColorPickerRow(title: "Font", selection: textFontColorDefaultBinding)
                ControlsCustomColorPickerRow(title: "BG", selection: textBackgroundColorDefaultBinding)

                AnnotationToolkitMiniSlider(
                    label: "Font Size",
                    valueText: "\(Int(editor.annotationTextDefaultFontSize.rounded()))",
                    value: textFontSizeDefaultBinding,
                    range: 10...40,
                    width: 220
                )
                .environmentObject(editor)

                HStack(spacing: 6) {
                    ForEach(EditorState.AnnotationTextAlignment.allCases, id: \.self) { alignment in
                        Button {
                            guard editor.annotationTextDefaultAlignment != alignment else { return }
                            editor.recordUndoCheckpoint()
                            editor.annotationTextDefaultAlignment = alignment
                        } label: {
                            Image(systemName: alignment.symbolName)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(editor.annotationTextDefaultAlignment == alignment ? .accentColor : .gray.opacity(0.45))
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
        .padding(10)
        .frame(width: 260)
    }

    private var drawAutoSmoothBinding: Binding<Bool> {
        Binding(
            get: {
                if let id = selectedDrawAnnotationID {
                    return editor.annotationDrawAutoSmoothOverrides[id] ?? editor.annotationDrawAutoSmooth
                }
                return editor.annotationDrawAutoSmooth
            },
            set: { newValue in
                let currentValue: Bool
                if let id = selectedDrawAnnotationID {
                    currentValue = editor.annotationDrawAutoSmoothOverrides[id] ?? editor.annotationDrawAutoSmooth
                    guard currentValue != newValue else { return }
                    editor.recordUndoCheckpoint()
                    editor.annotationDrawAutoSmoothOverrides[id] = newValue
                    return
                }

                currentValue = editor.annotationDrawAutoSmooth
                guard currentValue != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationDrawAutoSmooth = newValue
            }
        )
    }

    private var selectedDrawAnnotationID: UUID? {
        guard let selectedID = editor.selectedAnnotationID else { return nil }
        guard let selected = editor.annotations.first(where: { $0.id == selectedID }) else { return nil }
        return selected.kind == .draw ? selectedID : nil
    }

    private var textFontColorDefaultBinding: Binding<Color> {
        Binding(
            get: { editor.annotationTextDefaultFontColor },
            set: { newValue in
                guard editor.annotationTextDefaultFontColor != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationTextDefaultFontColor = newValue
            }
        )
    }

    private var textBackgroundColorDefaultBinding: Binding<Color> {
        Binding(
            get: { editor.annotationTextDefaultBackgroundColor },
            set: { newValue in
                guard editor.annotationTextDefaultBackgroundColor != newValue else { return }
                editor.recordUndoCheckpoint()
                editor.annotationTextDefaultBackgroundColor = newValue
            }
        )
    }

    private var textFontSizeDefaultBinding: Binding<CGFloat> {
        Binding(
            get: { editor.annotationTextDefaultFontSize },
            set: { editor.annotationTextDefaultFontSize = $0 }
        )
    }
}

private extension EditorState.AnnotationTool {
    var supportsToolkitPopover: Bool {
        switch self {
        case .box, .arrow, .lupe, .draw, .text:
            return true
        case .none, .hand:
            return false
        }
    }

    var supportsStrokeControl: Bool {
        switch self {
        case .box, .arrow, .lupe, .draw, .text:
            return true
        case .none, .hand:
            return false
        }
    }
}

private struct AnnotationToolkitMiniSlider: View {
    @EnvironmentObject private var editor: EditorState

    let label: String
    let valueText: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var width: CGFloat = 140

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
            .frame(width: width)
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06))
        )
    }
}

struct ControlsBackgroundSection: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        GroupBox(AppStrings.Controls.backgroundGroup) {
            ControlsSectionContent {
                HStack(spacing: 10) {
                    Text(AppStrings.Controls.style)
                    Spacer(minLength: 0)
                    Picker("", selection: backgroundStyleBinding) {
                        ForEach(EditorState.BackgroundStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                }

                if editor.backgroundStyle == .solid {
                    ControlsCustomColorPickerRow(title: AppStrings.Controls.color, selection: solidColorBinding)
                }
            }
        }
    }

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: { editor.solidColor },
            set: { newValue in
                editor.recordUndoCheckpoint()
                editor.solidColor = newValue
            }
        )
    }

    private var backgroundStyleBinding: Binding<EditorState.BackgroundStyle> {
        Binding(
            get: { editor.backgroundStyle },
            set: { newValue in
                editor.recordUndoCheckpoint()
                editor.backgroundStyle = newValue
            }
        )
    }
}

struct ControlsLayoutSection: View {
    @EnvironmentObject private var editor: EditorState
    @State private var isCustomLayoutSheetPresented = false
    @State private var customLayoutDraft = CustomLayoutDraft()
    private let ratioGridSpacing: CGFloat = 8
    private let ratioButtonWidth: CGFloat = 56
    private var aspectGridWidth: CGFloat { (ratioButtonWidth * 4) + (ratioGridSpacing * 3) }
    private var presetButtonWidth: CGFloat { (ratioButtonWidth * 2) + ratioGridSpacing }

    var body: some View {
        if editor.isOriginalStyleLayoutLocked {
            GroupBox(AppStrings.Controls.originalLayoutGroup) {
                ControlsSectionContent {
                    ControlsSliderRow(
                        label: AppStrings.Controls.zoom,
                        value: $editor.imageScale,
                        range: EditorState.LayoutRanges.zoom,
                        valueText: String(format: "%.2fx", editor.imageScale)
                    )
                    ControlsSliderRow(
                        label: AppStrings.Controls.outerRadius,
                        value: $editor.outerCornerRadius,
                        range: EditorState.LayoutRanges.outerCornerRadius,
                        valueText: nil
                    )
                    ControlsFullWidthButton(title: AppStrings.Controls.resetLayout) {
                        editor.resetLayoutAdjustments()
                    }
                }
            }
        } else {
            GroupBox(AppStrings.Controls.layoutGroup) {
                ControlsSectionContent {
                    Text(AppStrings.Controls.aspectRatio)
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(ratioButtonWidth), spacing: ratioGridSpacing, alignment: .leading),
                            count: 4
                        ),
                        alignment: .leading,
                        spacing: ratioGridSpacing
                    ) {
                        ForEach(EditorState.standardAspectPresets) { preset in
                            ControlsRatioButton(
                                label: preset.title,
                                ratio: preset.ratio,
                                isSelected: editor.selectedStandardAspectRatioID == preset.id
                            )
                        }
                    }
                    .frame(width: aspectGridWidth, alignment: .leading)

                    HStack(spacing: ratioGridSpacing) {
                        ControlsAppIconRatioButton()
                            .frame(width: presetButtonWidth)
                        ControlsCustomLayoutPresetButton {
                            customLayoutDraft = CustomLayoutDraft(editor: editor)
                            isCustomLayoutSheetPresented = true
                        }
                            .frame(width: presetButtonWidth)
                    }
                    .frame(width: aspectGridWidth, alignment: .leading)

                    if editor.isAppIconLayout {
                        HStack(spacing: 10) {
                            Text(AppStrings.Controls.iconShape)
                            Spacer(minLength: 0)
                            Picker("", selection: appIconShapeBinding) {
                                ForEach(EditorState.AppIconShape.allCases) { shape in
                                    Text(shape.title).tag(shape)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    ControlsSliderRow(
                        label: AppStrings.Controls.zoom,
                        value: $editor.imageScale,
                        range: EditorState.LayoutRanges.zoom,
                        valueText: String(format: "%.2fx", editor.imageScale)
                    )
                    ControlsSliderRow(
                        label: AppStrings.Controls.padding,
                        value: $editor.canvasPadding,
                        range: EditorState.LayoutRanges.padding,
                        valueText: nil
                    )
                    ControlsSliderRow(
                        label: AppStrings.Controls.outerRadius,
                        value: $editor.outerCornerRadius,
                        range: EditorState.LayoutRanges.outerCornerRadius,
                        valueText: nil
                    )
                    ControlsSliderRow(
                        label: AppStrings.Controls.cornerRadius,
                        value: $editor.imageCornerRadius,
                        range: EditorState.LayoutRanges.imageCornerRadius,
                        valueText: nil
                    )
                    ControlsSliderRow(
                        label: AppStrings.Controls.shadow,
                        value: $editor.shadowRadius,
                        range: EditorState.LayoutRanges.shadowRadius,
                        valueText: nil
                    )
                    ControlsShadowOpacityRow()

                    HStack(spacing: 8) {
                        Circle()
                            .fill(editor.isSubjectCentered ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(editor.centeringMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ControlsFullWidthButton(title: AppStrings.Controls.autoCenter) {
                        editor.autoCenterVertically()
                    }
                    .disabled(!editor.hasCenteringData)

                    ControlsFullWidthButton(title: AppStrings.Controls.resetLayout) {
                        editor.resetLayoutAdjustments()
                    }
                }
            }
            .sheet(isPresented: $isCustomLayoutSheetPresented) {
                ControlsCustomLayoutSheet(draft: $customLayoutDraft) { draft in
                    guard let ratio = draft.parsedAspectRatio else { return }
                    editor.applyCustomLayout(
                        aspectRatio: ratio,
                        outerCornerRadius: draft.outerCornerRadius
                    )
                }
            }
        }
    }

    private var appIconShapeBinding: Binding<EditorState.AppIconShape> {
        Binding(
            get: { editor.appIconShape },
            set: { newValue in
                editor.setAppIconShape(newValue)
            }
        )
    }
}

struct ControlsSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(AppStrings.Controls.settings, systemImage: "gearshape.fill")
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}

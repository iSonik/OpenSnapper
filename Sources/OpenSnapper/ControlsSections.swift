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
        Button(label) {
            editor.setAspectRatio(ratio)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? .accentColor : .gray.opacity(0.45))
    }
}

private struct ControlsAppIconRatioButton: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        Button(AppStrings.Controls.appIcon) {
            editor.applyAppIconLayoutPreset()
        }
        .buttonStyle(.borderedProminent)
        .tint(editor.isAppIconLayout ? .accentColor : .gray.opacity(0.45))
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
            }
        }
    }
}

struct ControlsToolkitSection: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        GroupBox(AppStrings.Controls.toolkitGroup) {
            ControlsSectionContent {
                ControlsFullWidthButton(title: AppStrings.Controls.pickColor) {
                    editor.pickColorFromScreen()
                }
                .disabled(!editor.hasScreenCaptureAccess)

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
                    ColorPicker(AppStrings.Controls.color, selection: solidColorBinding)
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
                    HStack {
                        ForEach(EditorState.standardAspectPresets) { preset in
                            ControlsRatioButton(
                                label: preset.title,
                                ratio: preset.ratio,
                                isSelected: editor.selectedStandardAspectRatioID == preset.id
                            )
                        }
                    }

                    HStack {
                        ControlsAppIconRatioButton()
                        Spacer(minLength: 0)
                    }

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
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

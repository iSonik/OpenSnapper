import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var editor: EditorState
    @State private var isDropTargeted = false
    @State private var copyFlash = false
    @State private var copyShakeTrigger: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if editor.shouldShowOnboarding {
                    OnboardingView()
                } else {
                    editorView
                }
            }

            if let toast = editor.toast {
                ToastView(message: toast.message, isError: toast.isError)
                    .padding(.trailing, 18)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: editor.toast?.id)
        .onChange(of: editor.copyFeedbackID) { id in
            guard id != nil else { return }
            triggerCopyFeedback()
        }
        .background(
            WindowAccessor { window in
                editor.registerMainWindow(window)
            }
        )
    }

    private var editorView: some View {
        HStack(spacing: 0) {
            ControlsView()
                .frame(width: 280)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            HStack(spacing: 0) {
                canvasWorkspace
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: editor.handleDrop)

                Divider()

                rightInspector
                    .frame(width: 330)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }

    private var canvasWorkspace: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if editor.hasImage {
                    ControlsAnnotationsTopBar()
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                }

                ZStack(alignment: .topTrailing) {
                    GeometryReader { geometry in
                        let canvasRect = calculatedCanvasRect(in: geometry.size)
                        let horizontalWidth = min(320, max(180, canvasRect.width * 0.44))
                        let verticalLength = min(240, max(140, canvasRect.height * 0.46))
                        let horizontalY = max(20, canvasRect.minY - 20)
                        let verticalX = min(geometry.size.width - 14, canvasRect.maxX + 16)

                        ZStack(alignment: .topLeading) {
                            CanvasView()
                                .frame(width: canvasRect.width, height: canvasRect.height)
                                .position(x: canvasRect.midX, y: canvasRect.midY)

                            if editor.hasImage {
                                Slider(
                                    value: horizontalPlacementBinding,
                                    in: EditorState.LayoutRanges.offset,
                                    onEditingChanged: { editing in
                                        if editing {
                                            editor.recordUndoCheckpoint()
                                        }
                                    }
                                )
                                .frame(width: horizontalWidth)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .position(x: canvasRect.midX, y: horizontalY)

                                Slider(
                                    value: verticalPlacementBinding,
                                    in: EditorState.LayoutRanges.offset,
                                    onEditingChanged: { editing in
                                        if editing {
                                            editor.recordUndoCheckpoint()
                                        }
                                    }
                                )
                                .frame(width: verticalLength)
                                .rotationEffect(.degrees(-90))
                                .scaleEffect(x: 1, y: -1)
                                .frame(width: 24, height: verticalLength)
                                .position(x: verticalX, y: canvasRect.midY)
                            }

                            if isDropTargeted {
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                                    .frame(width: canvasRect.width, height: canvasRect.height)
                                    .position(x: canvasRect.midX, y: canvasRect.midY)
                            }
                        }
                    }
                }

                HStack {
                    Spacer(minLength: 0)
                    copyButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }

    private var rightInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ControlsBackgroundSection()
                ControlsLayoutSection()
                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .groupBoxStyle(ControlsGlassGroupBoxStyle())
    }

    private var copyButton: some View {
        Button {
            editor.copyEditedImageToClipboard()
        } label: {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 32)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle)
        .controlSize(.large)
        .disabled(!editor.hasImage)
        .foregroundStyle(copyFlash ? .green : .primary)
        .shadow(color: copyFlash ? .green.opacity(0.45) : .clear, radius: 8)
        .modifier(ShakeEffect(animatableData: copyShakeTrigger))
    }

    private func triggerCopyFeedback() {
        withAnimation(.easeOut(duration: 0.2)) {
            copyFlash = true
        }
        withAnimation(.linear(duration: 0.38)) {
            copyShakeTrigger += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.2)) {
                copyFlash = false
            }
        }
    }

    private var horizontalPlacementBinding: Binding<CGFloat> {
        Binding(
            get: { editor.imageOffsetX },
            set: { editor.imageOffsetX = $0 }
        )
    }

    private var verticalPlacementBinding: Binding<CGFloat> {
        Binding(
            get: { editor.imageOffsetY },
            set: { editor.imageOffsetY = $0 }
        )
    }

    private func calculatedCanvasRect(in size: CGSize) -> CGRect {
        let inset: CGFloat = 28
        let availableWidth = max(1, size.width - (inset * 2))
        let availableHeight = max(1, size.height - (inset * 2))
        let aspect = activeCanvasAspect
        let fitted = fittedSize(width: availableWidth, height: availableHeight, aspect: aspect)

        let originX = (size.width - fitted.width) / 2
        let originY = (size.height - fitted.height) / 2
        return CGRect(x: originX, y: originY, width: fitted.width, height: fitted.height)
    }

    private var activeCanvasAspect: CGFloat {
        return max(editor.aspectRatio, 0.1)
    }

    private func fittedSize(width: CGFloat, height: CGFloat, aspect: CGFloat) -> CGSize {
        let clampedAspect = max(aspect, 0.1)
        let containerAspect = width / height
        if containerAspect > clampedAspect {
            let fittedHeight = height
            return CGSize(width: fittedHeight * clampedAspect, height: fittedHeight)
        } else {
            let fittedWidth = width
            return CGSize(width: fittedWidth, height: fittedWidth / clampedAspect)
        }
    }
}

struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        Text(message)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    private var backgroundColor: Color {
        isError ? Color.red.opacity(0.92) : Color.green.opacity(0.88)
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 8) * 5
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

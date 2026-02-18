import Foundation

extension EditorState {
    var hasImage: Bool { sourceImage != nil }
    var isOriginalStyleLayoutLocked: Bool { backgroundStyle == .original }
    var shouldShowOnboarding: Bool { !hasScreenCaptureAccess && !skipOnboarding }
    var hasCenteringData: Bool { centeringEnabled && detectedSubjectCenterX != nil && detectedSubjectCenterY != nil }
    var canUndo: Bool { !undoStack.isEmpty }
    var hasDefaultSaveFolder: Bool { !defaultSaveFolderPath.isEmpty }
    var defaultSaveFolderURL: URL? {
        guard !defaultSaveFolderPath.isEmpty else { return nil }
        return URL(fileURLWithPath: defaultSaveFolderPath, isDirectory: true)
    }
}

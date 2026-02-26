import Foundation

enum AppStrings {
    enum App {
        static let name = "OpenSnapper"
        static let hideToMenuBar = "Hide to Menu Bar"
    }

    enum Controls {
        static let imageGroup = "Image"
        static let toolkitGroup = "Toolkit"
        static let backgroundGroup = "Background"
        static let layoutGroup = "Layout"
        static let originalLayoutGroup = "Layout (Original)"
        static let selectArea = "Select Area"
        static let wholeScreen = "Whole Screen"
        static let selectImage = "Select Image"
        static let save = "Save"
        static let saveAs = "Save As..."
        static let openInFinder = "Open in Finder"
        static let dragSavedFile = "Drag Saved File"
        static let annotations = "Annotations"
        static let annotationTool = "Tool"
        static let annotationPreset = "Preset"
        static let annotationText = "Text"
        static let clearAnnotationsButton = "Clear Annotations"
        static let pickColor = "Pick Color"
        static let isolateSubject = "Isolate Subject (AI)"
        static let isolating = "Isolating..."
        static let removeSolidBackground = "Remove Solid Background"
        static let removing = "Removing..."
        static let style = "Style"
        static let color = "Color"
        static let aspectRatio = "Aspect Ratio"
        static let iconShape = "Icon Shape"
        static let appIcon = "App Icon"
        static let customPreset = "Custom"
        static let zoom = "Zoom"
        static let padding = "Padding"
        static let outerRadius = "Outer Radius"
        static let cornerRadius = "Corner Radius"
        static let shadow = "Shadow"
        static let shadowOpacity = "Shadow Opacity"
        static let autoCenter = "Auto Center"
        static let resetLayout = "Reset Layout"
        static let settings = "Settings"
    }

    enum Canvas {
        static let dropImage = "Drop an image"
        static let dropImageHint = "or use Open / Paste from Clipboard"
        static let dropImageSymbol = "photo.badge.plus"
    }

    enum StatusBar {
        static let tooltip = App.name
        static let enableScreenRecording = "Enable Screen Recording"
        static let quit = "Quit OpenSnapper"
        static let captureScreenshot = "Capture Screenshot"
        static let captureWholeScreen = "Capture Whole Screen"
        static let colorPick = "Color Pick"
        static let openApp = "Open App"
        static let settings = "Settings"

        static func hover(_ hex: String) -> String {
            "Hover: \(hex)"
        }
    }

    enum Messages {
        static let noImageSelected = "No image selected"
        static let clipboardHasNoImage = "Clipboard has no image"
        static let failedToLoadImage = "Failed to load image"
        static let loadedFromClipboard = "Loaded from clipboard"
        static let removeBGRequiresMacOS14 = "Remove BG requires macOS 14+"
        static let failedToReadImage = "Failed to read image"
        static let isolatingSubject = "Isolating subject..."
        static let subjectIsolated = "Subject isolated"
        static let removingSolidBackground = "Removing solid background..."
        static let solidBackgroundRemoved = "Solid background removed"
        static let captureAlreadyInProgress = "Capture already in progress"
        static let captureCanceled = "Capture canceled"
        static let fullScreenCaptureCanceled = "Full-screen capture canceled"
        static let captureStartSelectArea = "Select area/window to capture"
        static let captureStartFullScreen = "Capturing full screen..."
        static let captureSuccess = "Captured screenshot"
        static let captureSuccessFullScreen = "Captured full screen"
        static let captureFailurePrefix = "Capture failed"
        static let captureFailurePrefixFullScreen = "Full-screen capture failed"
        static let screenCaptureEnabled = "Screen capture enabled"
        static let permissionGrantedLoading = "Permission granted. Loading editor..."
        static let permissionNotGranted = "Permission not granted yet."
        static let permissionDeniedEnableInSettings = "Permission denied. Enable it in System Settings."
        static let openSettingsToEnableScreenRecording = "Open System Settings to enable Screen Recording"
        static let enableScreenRecordingAndReturn = "Enable Screen Recording for OpenSnapper in System Settings, then return and click I've Enabled It."
        static let stillBlockedReopen = "Still blocked. If just enabled in Settings, quit and reopen OpenSnapper."
        static let openEditorRecheckPermission = "Open editor. Capture will re-check permission."
        static let colorPickerAlreadyActive = "Color picker already active"
        static let colorPickerCanceled = "Color picker canceled"
        static let capturePermissionError = "Enable Screen Recording to capture screenshots"
        static let colorPickPermissionError = "Enable Screen Recording to pick colors"
        static let runningInBackground = "OpenSnapper is running in background"
        static let nothingToUndo = "Nothing to undo"
        static let undidLastChange = "Undid last change"
        static let appliedAppIconLayout = "Applied App Icon layout"
        static let appliedCustomLayout = "Applied custom layout"
        static let resetLayout = "Reset layout"
        static let autoCenterAfterRemoveBackground = "Auto center is available after Remove Background"
        static let analyzingCentering = "Analyzing centering..."
        static let centeringAfterRemoveBackground = "Centering available after Remove Background"
        static let loadImageToAnalyzeCentering = "Load an image to analyze centering"
        static let visionCouldNotDetectCenter = "Vision could not detect subject center"
        static let contentCentered = "Content is centered"
        static let leftPx = "left"
        static let rightPx = "right"
        static let upPx = "up"
        static let downPx = "down"
        static let clearAnnotations = "Cleared annotations"
        static let clearRedactions = "Cleared redactions"
        static let scanSensitiveText = "Scanning for sensitive text..."
        static let noSensitiveTextFound = "No sensitive text found"
        static let sensitiveTextRedacted = "Sensitive text redacted"
        static let nothingToSave = "Nothing to save"
        static let failedToRenderImage = "Failed to render image"
        static let setDefaultFolderOrAsk = "Set default folder or enable Ask Every Time"
        static let saveCanceled = "Save canceled"
        static let nothingToCopy = "Nothing to copy"
        static let copyFailed = "Copy failed"
        static let copiedImageToClipboard = "Copied image to clipboard"
        static let screenshotNotFound = "Screenshot not found"
        static let copiedScreenshotToClipboard = "Copied screenshot to clipboard"
        static let copiedScreenshotToast = "Copied screenshot"
        static let launchAtLoginRequiresMacOS13 = "Launch at login requires macOS 13+"
        static let launchAtLoginEnabled = "Launch at login enabled"
        static let launchAtLoginDisabled = "Launch at login disabled"
        static let defaultFilenameTemplate = "screenshot_{date}_{time}"
        static let defaultFilenameFallbackBase = "screenshot"
        static let unresolvedFilenameFallback = "screenshot_"

        static func screenshotLabel(_ time: String) -> String {
            "Screenshot \(time)"
        }

        static func loadedImage(_ name: String) -> String {
            "Loaded \(name)"
        }

        static func copiedColor(_ hex: String) -> String {
            "Copied color \(hex)"
        }

        static func captureFailure(_ prefix: String, _ detail: Substring) -> String {
            "\(prefix): \(detail)"
        }

        static func isolateFailed(_ detail: String) -> String {
            "Isolate failed: \(detail)"
        }

        static func solidBackgroundFailed(_ detail: String) -> String {
            "Solid BG failed: \(detail)"
        }

        static func redactionFailed(_ detail: String) -> String {
            "Redaction failed: \(detail)"
        }

        static func addedRedactions(_ count: Int) -> String {
            "Added \(count) redactions"
        }

        static func arrowAdded(for kind: String) -> String {
            "\(kind) added"
        }

        static func appIconShape(_ title: String) -> String {
            "App icon shape: \(title)"
        }

        static func move(_ text: String) -> String {
            "Move \(text)"
        }

        static func moveBoth(horizontal: String, vertical: String) -> String {
            "Move \(horizontal), \(vertical)"
        }

        static func directionPixels(_ direction: String, _ px: Int) -> String {
            "\(direction) \(px) px"
        }

        static func failedToEncode(_ format: String) -> String {
            "Failed to encode \(format)"
        }

        static func saved(_ filename: String) -> String {
            "Saved \(filename)"
        }

        static func savedAndRevealed(_ filename: String) -> String {
            "Saved and revealed \(filename)"
        }

        static func saveFailed(_ detail: String) -> String {
            "Save failed: \(detail)"
        }

        static func captureFailure(_ prefix: String, _ detail: String) -> String {
            "\(prefix): \(detail)"
        }

        static func launchAtLoginUpdateFailed(_ detail: String) -> String {
            "Launch at login update failed: \(detail)"
        }
    }
}

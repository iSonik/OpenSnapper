import AppKit
import Carbon
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class EditorState: ObservableObject {
    @Published var sourceImage: NSImage?
    @Published var backgroundStyle: BackgroundStyle = .aurora {
        didSet {
            if backgroundStyle == .original {
                applyOriginalLayoutLock()
            }
            updateCenteringIndicator()
        }
    }
    @Published var solidColor: Color = Color(red: 0.12, green: 0.12, blue: 0.14)
    @Published var canvasPadding: CGFloat = LayoutDefaults.canvasPadding {
        didSet { updateCenteringIndicator() }
    }
    @Published var outerCornerRadius: CGFloat = LayoutDefaults.outerCornerRadius
    @Published var imageCornerRadius: CGFloat = LayoutDefaults.imageCornerRadius
    @Published var shadowRadius: CGFloat = LayoutDefaults.shadowRadius
    @Published var shadowOpacity: Double = LayoutDefaults.shadowOpacity
    @Published var imageScale: CGFloat = LayoutDefaults.imageScale {
        didSet { updateCenteringIndicator() }
    }
    @Published var imageOffsetX: CGFloat = LayoutDefaults.imageOffsetX {
        didSet { updateCenteringIndicator() }
    }
    @Published var imageOffsetY: CGFloat = LayoutDefaults.imageOffsetY {
        didSet { updateCenteringIndicator() }
    }
    @Published var aspectRatio: CGFloat = 16.0 / 10.0 {
        didSet { updateCenteringIndicator() }
    }
    @Published var isAppIconLayout: Bool = false
    @Published var appIconShape: AppIconShape = .classic
    @Published var statusMessage: String = AppStrings.Messages.noImageSelected
    @Published var hasScreenCaptureAccess: Bool = false
    @Published var onboardingMessage: String = "Permission not granted yet."
    @Published var skipOnboarding: Bool = false
    @Published var isRemovingBackground: Bool = false
    @Published var backgroundRemovalMode: BackgroundRemovalMode?
    @Published var centeringMessage: String = "Centering unavailable"
    @Published var isSubjectCentered: Bool = false
    @Published var toast: ToastMessage?
    @Published var copyFeedbackID: UUID?
    @Published var defaultSaveFolderPath: String = "" {
        didSet { persistPreferences() }
    }
    @Published var filenameTemplate: String = "screenshot_{date}_{time}" {
        didSet { persistPreferences() }
    }
    @Published var exportFormat: ExportFormat = .png {
        didSet { persistPreferences() }
    }
    @Published var askForSaveLocationEachTime: Bool = true {
        didSet { persistPreferences() }
    }
    @Published var closeAppOnCopyShortcut: Bool = false {
        didSet { persistPreferences() }
    }
    @Published var captureHotkey: String = "cmd+shift+2" {
        didSet {
            persistPreferences()
            registerGlobalHotkeys()
        }
    }
    @Published var exportHotkey: String = "cmd+e" {
        didSet {
            persistPreferences()
            registerGlobalHotkeys()
        }
    }
    @Published var colorPickerHotkey: String = "cmd+shift+p" {
        didSet {
            persistPreferences()
            registerGlobalHotkeys()
        }
    }
    @Published var launchAtLogin: Bool = false {
        didSet {
            guard !isLoadingPreferences, !isUpdatingLaunchAtLogin else { return }
            persistPreferences()
            applyLaunchAtLoginSettingIfNeeded()
        }
    }
    @Published var annotationTool: AnnotationTool = .none
    @Published var annotationStylePreset: AnnotationStylePreset = .callout
    @Published var annotationCustomColor: Color = Color(red: 0.11, green: 0.61, blue: 0.97)
    @Published var annotationTextDraft: String = "Text"
    @Published var editingTextAnnotationID: UUID?
    @Published var selectedAnnotationID: UUID?
    @Published var annotations: [Annotation] = []
    @Published var redactionRegions: [SensitiveRegion] = []
    @Published var draftAnnotationStart: CGPoint?
    @Published var draftAnnotationCurrent: CGPoint?
    @Published var recentPickedColors: [String] = []
    @Published var recentScreenshots: [RecentScreenshot] = []
    @Published var isColorPickerActive: Bool = false
    @Published var liveHoverColorHex: String?
    @Published var canvasSize: CGSize = .zero
    var captureProcess: Process?
    var captureWindows: [NSWindow] = []
    var captureWindowStates: [ObjectIdentifier: (alpha: CGFloat, ignoresMouseEvents: Bool)] = [:]
    var activeColorSampler: NSColorSampler?
    var hoverColorTimer: Timer?
    weak var mainWindow: NSWindow?
    var mainWindowDelegate: MainWindowDelegate?
    var detectedSubjectCenterX: CGFloat?
    var detectedSubjectCenterY: CGFloat?
    var centeringSource: CenteringSource?
    private var toastDismissWorkItem: DispatchWorkItem?
    var undoStack: [Snapshot] = []
    var isApplyingSnapshot = false
    var isLoadingPreferences = false
    var isUpdatingLaunchAtLogin = false
    var globalHotkeyHandler: EventHandlerRef?
    var globalHotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    let globalHotkeySignature: OSType = 0x4F534E50

    var centeringEnabled = false

    init() {
        loadPreferences()
        syncLaunchAtLoginStateFromSystem()
        refreshScreenCaptureAccess()
        installGlobalHotkeyHandlerIfNeeded()
        registerGlobalHotkeys()
    }

    func setStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        if isError {
            showToast(message, isError: true)
        }
    }

    func showToast(_ message: String, isError: Bool) {
        toastDismissWorkItem?.cancel()
        toast = ToastMessage(message: message, isError: isError)

        let workItem = DispatchWorkItem { [weak self] in
            self?.toast = nil
        }
        toastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: workItem)
    }

}

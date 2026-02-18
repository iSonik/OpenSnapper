import AppKit
import CoreGraphics
import Foundation

extension EditorState {
    private enum ScreenCapturePermissionDefaults {
        static let settingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    }

    func ensureScreenCaptureAccess(errorMessage: String) -> Bool {
        refreshScreenCaptureAccess()
        guard hasScreenCaptureAccess else {
            setStatus(errorMessage, isError: true)
            return false
        }
        return true
    }

    func refreshScreenCaptureAccess() {
        hasScreenCaptureAccess = hasScreenCapturePermissionRightNow()
        if hasScreenCaptureAccess {
            skipOnboarding = false
        }

        onboardingMessage = hasScreenCaptureAccess
            ? AppStrings.Messages.permissionGrantedLoading
            : AppStrings.Messages.permissionNotGranted
        registerGlobalHotkeys()
    }

    @discardableResult
    func requestScreenCaptureAccess() -> Bool {
        if #available(macOS 10.15, *) {
            let requested = CGRequestScreenCaptureAccess()
            hasScreenCaptureAccess = requested || CGPreflightScreenCaptureAccess()
        } else {
            hasScreenCaptureAccess = true
        }
        if hasScreenCaptureAccess {
            skipOnboarding = false
        }

        if hasScreenCaptureAccess {
            setStatus(AppStrings.Messages.screenCaptureEnabled)
            onboardingMessage = AppStrings.Messages.permissionGrantedLoading
        } else {
            onboardingMessage = AppStrings.Messages.permissionDeniedEnableInSettings
        }
        registerGlobalHotkeys()

        return hasScreenCaptureAccess
    }

    func requestScreenCaptureAndOpenSettingsIfNeeded() {
        refreshScreenCaptureAccess()
        if hasScreenCaptureAccess {
            setStatus(AppStrings.Messages.screenCaptureEnabled)
            return
        }

        let granted = requestScreenCaptureAccess()
        if !granted {
            openScreenRecordingSettings()
            onboardingMessage = AppStrings.Messages.enableScreenRecordingAndReturn
            setStatus(AppStrings.Messages.openSettingsToEnableScreenRecording)
        }
    }

    func confirmPermissionFromOnboarding() {
        refreshScreenCaptureAccess()
        if hasScreenCaptureAccess {
            setStatus(AppStrings.Messages.screenCaptureEnabled)
            return
        }

        let granted = requestScreenCaptureAccess()
        if !granted {
            onboardingMessage = AppStrings.Messages.stillBlockedReopen
            skipOnboarding = true
            setStatus(AppStrings.Messages.openEditorRecheckPermission)
        }
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: ScreenCapturePermissionDefaults.settingsURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

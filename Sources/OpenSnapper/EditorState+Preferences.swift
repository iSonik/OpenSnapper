import Foundation
import ServiceManagement

extension EditorState {
    func clearDefaultSaveFolder() {
        defaultSaveFolderPath = ""
    }

    func setDefaultSaveFolder(url: URL) {
        defaultSaveFolderPath = url.path
    }

    private enum DefaultsKey {
        static let defaultSaveFolderPath = "settings.defaultSaveFolderPath"
        static let filenameTemplate = "settings.filenameTemplate"
        static let exportFormat = "settings.exportFormat"
        static let askForSaveLocationEachTime = "settings.askForSaveLocationEachTime"
        static let captureHotkey = "settings.captureHotkey"
        static let exportHotkey = "settings.exportHotkey"
        static let colorPickerHotkey = "settings.colorPickerHotkey"
        static let launchAtLogin = "settings.launchAtLogin"
    }

    func loadPreferences() {
        isLoadingPreferences = true
        defer { isLoadingPreferences = false }

        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: DefaultsKey.defaultSaveFolderPath) {
            defaultSaveFolderPath = value
        }
        if let value = defaults.string(forKey: DefaultsKey.filenameTemplate), !value.isEmpty {
            filenameTemplate = value
        }
        if
            let value = defaults.string(forKey: DefaultsKey.exportFormat),
            let parsed = ExportFormat(rawValue: value)
        {
            exportFormat = parsed
        }
        if defaults.object(forKey: DefaultsKey.askForSaveLocationEachTime) != nil {
            askForSaveLocationEachTime = defaults.bool(forKey: DefaultsKey.askForSaveLocationEachTime)
        }
        if let value = defaults.string(forKey: DefaultsKey.captureHotkey), !value.isEmpty {
            captureHotkey = value
        }
        if let value = defaults.string(forKey: DefaultsKey.exportHotkey), !value.isEmpty {
            exportHotkey = value
        }
        if let value = defaults.string(forKey: DefaultsKey.colorPickerHotkey), !value.isEmpty {
            colorPickerHotkey = value
        }
        if defaults.object(forKey: DefaultsKey.launchAtLogin) != nil {
            launchAtLogin = defaults.bool(forKey: DefaultsKey.launchAtLogin)
        }
    }

    func persistPreferences() {
        guard !isLoadingPreferences else { return }

        let defaults = UserDefaults.standard
        defaults.set(defaultSaveFolderPath, forKey: DefaultsKey.defaultSaveFolderPath)
        defaults.set(filenameTemplate, forKey: DefaultsKey.filenameTemplate)
        defaults.set(exportFormat.rawValue, forKey: DefaultsKey.exportFormat)
        defaults.set(askForSaveLocationEachTime, forKey: DefaultsKey.askForSaveLocationEachTime)
        defaults.set(captureHotkey, forKey: DefaultsKey.captureHotkey)
        defaults.set(exportHotkey, forKey: DefaultsKey.exportHotkey)
        defaults.set(colorPickerHotkey, forKey: DefaultsKey.colorPickerHotkey)
        defaults.set(launchAtLogin, forKey: DefaultsKey.launchAtLogin)
    }

    func syncLaunchAtLoginStateFromSystem() {
        guard #available(macOS 13.0, *) else { return }
        isUpdatingLaunchAtLogin = true
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        isUpdatingLaunchAtLogin = false
    }

    func applyLaunchAtLoginSettingIfNeeded() {
        guard #available(macOS 13.0, *) else {
            setStatus(AppStrings.Messages.launchAtLoginRequiresMacOS13, isError: true)
            isUpdatingLaunchAtLogin = true
            launchAtLogin = false
            isUpdatingLaunchAtLogin = false
            return
        }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
                showToast(AppStrings.Messages.launchAtLoginEnabled, isError: false)
            } else {
                try SMAppService.mainApp.unregister()
                showToast(AppStrings.Messages.launchAtLoginDisabled, isError: false)
            }
        } catch {
            isUpdatingLaunchAtLogin = true
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            isUpdatingLaunchAtLogin = false
            setStatus(AppStrings.Messages.launchAtLoginUpdateFailed(error.localizedDescription), isError: true)
        }
    }
}

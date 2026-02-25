import AppKit
import Foundation

extension EditorState {
    private enum ScreenCaptureDefaults {
        static let executablePath = "/usr/sbin/screencapture"
        static let launchDelaySeconds: TimeInterval = 0.15
        static let permissionError = AppStrings.Messages.capturePermissionError
        static let errorMessagePreviewLength = 120
        static let recentScreenshotsLimit = 5
    }

    func captureScreenshot() {
        startScreenCapture(
            arguments: ["-i"],
            outputPrefix: "opensnapper-capture",
            startMessage: AppStrings.Messages.captureStartSelectArea,
            successMessage: AppStrings.Messages.captureSuccess,
            canceledMessage: AppStrings.Messages.captureCanceled,
            failurePrefix: AppStrings.Messages.captureFailurePrefix,
            allowPasteboardFallback: true
        )
    }

    func captureWholeScreen() {
        startScreenCapture(
            arguments: ["-x"],
            outputPrefix: "opensnapper-fullscreen",
            startMessage: AppStrings.Messages.captureStartFullScreen,
            successMessage: AppStrings.Messages.captureSuccessFullScreen,
            canceledMessage: AppStrings.Messages.fullScreenCaptureCanceled,
            failurePrefix: AppStrings.Messages.captureFailurePrefixFullScreen,
            allowPasteboardFallback: false
        )
    }

    func rememberRecentScreenshot(_ image: NSImage) {
        var updated = recentScreenshots
        updated.insert(
            RecentScreenshot(image: image, label: AppStrings.Messages.screenshotLabel(Self.screenshotTimeString())),
            at: 0
        )
        if updated.count > ScreenCaptureDefaults.recentScreenshotsLimit {
            updated = Array(updated.prefix(ScreenCaptureDefaults.recentScreenshotsLimit))
        }
        recentScreenshots = updated
    }

    private func startScreenCapture(
        arguments: [String],
        outputPrefix: String,
        startMessage: String,
        successMessage: String,
        canceledMessage: String,
        failurePrefix: String,
        allowPasteboardFallback: Bool
    ) {
        guard ensureScreenCaptureAccess(errorMessage: ScreenCaptureDefaults.permissionError) else {
            return
        }

        if captureProcess != nil {
            setStatus(AppStrings.Messages.captureAlreadyInProgress)
            return
        }

        setStatus(startMessage)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(outputPrefix)-\(UUID().uuidString).png")
        let stderrPipe = Pipe()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ScreenCaptureDefaults.executablePath)
        process.arguments = arguments + [outputURL.path]
        process.standardError = stderrPipe
        captureProcess = process

        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor in
                guard let self else { return }
                defer { self.captureProcess = nil }
                let hadVisibleWindowsBeforeCapture = !self.captureWindows.isEmpty
                self.restoreWindowsAfterCapture()

                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrOutput = String(data: stderrData, encoding: .utf8) ?? ""
                let trimmed = stderrOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasCanceled = terminatedProcess.terminationStatus != 0 && trimmed.isEmpty

                if terminatedProcess.terminationStatus == 0,
                   FileManager.default.fileExists(atPath: outputURL.path)
                {
                    self.loadImage(
                        from: outputURL,
                        successMessage: successMessage,
                        storeAsRecentScreenshot: true,
                        resetLayout: true
                    )
                    self.cleanupCaptureTemporaryFile(at: outputURL)
                    self.bringMainWindowToFront()
                    return
                }

                if allowPasteboardFallback,
                   !wasCanceled,
                   let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
                {
                    self.rememberRecentScreenshot(image)
                    self.applySourceImage(
                        image,
                        successMessage: successMessage,
                        centeringEligible: false,
                        resetLayout: true
                    )
                    self.cleanupCaptureTemporaryFile(at: outputURL)
                    self.bringMainWindowToFront()
                    return
                }

                if trimmed.isEmpty {
                    self.setStatus(canceledMessage)
                } else {
                    self.setStatus(AppStrings.Messages.captureFailure(
                        failurePrefix,
                        trimmed.prefix(ScreenCaptureDefaults.errorMessagePreviewLength)
                    ), isError: true)
                }
                self.cleanupCaptureTemporaryFile(at: outputURL)
                if hadVisibleWindowsBeforeCapture {
                    self.bringMainWindowToFront()
                }
            }
        }

        hideWindowsForCapture()
        DispatchQueue.main.asyncAfter(deadline: .now() + ScreenCaptureDefaults.launchDelaySeconds) {
            do {
                try process.run()
            } catch {
                Task { @MainActor in
                    self.captureProcess = nil
                    self.setStatus("\(failurePrefix): \(error.localizedDescription)", isError: true)
                    self.cleanupCaptureTemporaryFile(at: outputURL)
                    self.restoreWindowsAfterCapture()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func cleanupCaptureTemporaryFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func hideWindowsForCapture() {
        captureWindows.removeAll()
        captureWindowStates.removeAll()

        for window in NSApplication.shared.windows where window.isVisible {
            let key = ObjectIdentifier(window)
            captureWindows.append(window)
            captureWindowStates[key] = (alpha: window.alphaValue, ignoresMouseEvents: window.ignoresMouseEvents)
            window.alphaValue = 0
            window.ignoresMouseEvents = true
        }
    }

    private func restoreWindowsAfterCapture() {
        for window in captureWindows {
            let key = ObjectIdentifier(window)
            if let state = captureWindowStates[key] {
                window.alphaValue = state.alpha
                window.ignoresMouseEvents = state.ignoresMouseEvents
            }
            window.orderFrontRegardless()
        }

        captureWindows.removeAll()
        captureWindowStates.removeAll()
    }

    private static func screenshotTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

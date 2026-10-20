import AppKit
import Observation
import RadaKit
import Speech

/// UI state of the settings window that does not belong in `AppSettings`.
@MainActor
@Observable
final class SettingsModel {
    var selection: SettingsSection? = .general
    var dictionarySearch = ""

    private(set) var isRecordingShortcut = false
    private(set) var shortcutMessage: String?

    private(set) var launchAtLogin = LaunchAtLogin.isEnabled
    private(set) var launchAtLoginError: String?

    private(set) var appleAssets: AppleAssetsState = .unknown

    enum AppleAssetsState: Equatable {
        case unknown, unavailable, unsupported, notInstalled, installing, installed
        case failed(String)
    }

    @ObservationIgnored private var keyMonitor: Any?

    // MARK: - Shortcut recording

    func startRecordingShortcut(app: AppModel) {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true
        shortcutMessage = nil
        app.suspendShortcut()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.capture(event, app: app) }
            return nil
        }
    }

    func stopRecordingShortcut(app: AppModel) {
        guard isRecordingShortcut else { return }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        isRecordingShortcut = false
        app.resumeShortcut()
    }

    private func capture(_ event: NSEvent, app: AppModel) {
        let shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: event.modifierFlags)
        if shortcut == .escape { return stopRecordingShortcut(app: app) }
        guard shortcut.isValidGlobalShortcut else {
            shortcutMessage = "Добавьте ⌘, ⌥, ⌃ или ⇧"
            return
        }
        stopRecordingShortcut(app: app)
        if !app.applyShortcut(shortcut) {
            shortcutMessage = "\(shortcut.displayString) занято другим приложением"
        }
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Apple language assets

    func refreshAppleAssets(for language: RecognitionLanguage) async {
        guard #available(macOS 26, *) else {
            appleAssets = .unavailable
            return
        }
        guard appleAssets != .installing else { return }
        appleAssets = switch await AppleDictationEngine.assetStatus(for: language) {
        case .installed: .installed
        case .unsupported: .unsupported
        case .downloading: .installing
        default: .notInstalled
        }
    }

    func installAppleAssets(for language: RecognitionLanguage) async {
        guard #available(macOS 26, *) else { return }
        appleAssets = .installing
        do {
            try await AppleDictationEngine.installAssets(for: language)
            appleAssets = .installed
        } catch {
            appleAssets = .failed(error.localizedDescription)
        }
    }
}

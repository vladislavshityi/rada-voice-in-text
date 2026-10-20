import AppKit
import Observation
import RadaKit

/// Composition root: owns every service and connects them.
@MainActor
@Observable
final class AppModel {
    let settings = AppSettings()
    let dictionary = DictionaryStore()
    let permissions = Permissions()
    let modelInstaller = ModelInstaller()
    let controller: DictationController

    /// `false` when another app already owns the configured shortcut.
    private(set) var shortcutAvailable = true

    @ObservationIgnored private let hotkeys = HotkeyCenter()
    @ObservationIgnored private lazy var hud = HUDController(controller: controller)
    @ObservationIgnored private lazy var settingsWindow = SettingsWindowController(app: self)

    init() {
        controller = DictationController(
            settings: settings, dictionary: dictionary, permissions: permissions, modelInstaller: modelInstaller
        )
    }

    func launch() {
        hotkeys.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .toggleDictation: controller.toggle()
            case .cancelDictation: controller.cancel()
            }
        }
        controller.onPhaseChange = { [weak self] phase in self?.phaseDidChange(phase) }
        shortcutAvailable = hotkeys.register(settings.shortcut, for: .toggleDictation)

        if needsSetup { openSettings() }
    }

    /// True until the essentials for the main scenario are in place.
    var needsSetup: Bool {
        permissions.microphone != .granted
            || !permissions.accessibilityGranted
            || (settings.engine == .whisper && !modelInstaller.isInstalled)
    }

    // MARK: - Shortcut

    /// Registers a new dictation shortcut; keeps the old one if the new one is taken.
    @discardableResult
    func applyShortcut(_ shortcut: Shortcut) -> Bool {
        guard hotkeys.register(shortcut, for: .toggleDictation) else {
            hotkeys.register(settings.shortcut, for: .toggleDictation)
            return false
        }
        settings.shortcut = shortcut
        shortcutAvailable = true
        return true
    }

    /// Lets the shortcut recorder capture the current combination itself.
    func suspendShortcut() {
        hotkeys.unregister(.toggleDictation)
    }

    func resumeShortcut() {
        shortcutAvailable = hotkeys.register(settings.shortcut, for: .toggleDictation)
    }

    // MARK: - Actions

    func openSettings(_ section: SettingsSection? = nil) {
        settingsWindow.show(section)
    }

    func copyLastTranscript() {
        guard let text = controller.lastTranscript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func deleteModel() {
        controller.releaseEngines()
        modelInstaller.remove()
    }

    func resetSettings() {
        settings.reset()
        applyShortcut(settings.shortcut)
    }

    func deleteAllData() {
        dictionary.removeAll()
        deleteModel()
        resetSettings()
        try? FileManager.default.removeItem(at: AppPaths.applicationSupport)
    }

    // MARK: - Phase changes

    private func phaseDidChange(_ phase: DictationController.Phase) {
        // Esc is intercepted only while there is something to cancel.
        if controller.isBusy {
            hotkeys.register(.escape, for: .cancelDictation)
        } else {
            hotkeys.unregister(.cancelDictation)
        }
        hud.present(phase)

        if case .failed(let issue) = phase {
            switch issue.settingsDestination {
            case .microphonePermission: openSettings(.general)
            case .recognition: openSettings(.recognition)
            case nil: break
            }
        }
    }
}

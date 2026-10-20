import AppKit
import RadaKit
import SwiftUI
import UniformTypeIdentifiers

/// Hosts file transcription in a regular window. Closing it does not stop a
/// running transcription: progress stays visible in the menu bar menu.
@MainActor
final class FileTranscriptionWindowController: NSObject, NSWindowDelegate {
    private let app: AppModel
    private let model = FileWindowModel()
    private var window: NSWindow?

    init(app: AppModel) {
        self.app = app
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        DockPresence.windowOpened(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Расшифровка файла"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 560, height: 420)
        window.contentViewController = NSHostingController(
            rootView: FileTranscriptionView(app: app, files: app.files, model: model)
        )
        window.setContentSize(CGSize(width: 720, height: 560))
        window.center()
        window.setFrameAutosaveName("RadaFileTranscription")
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        if let window { DockPresence.windowClosed(window) }
    }
}

/// View state that SwiftUI's `@State` would normally hold (unavailable without Xcode's macro plugin).
@MainActor
@Observable
final class FileWindowModel {
    var isDropTargeted = false
    var copied = false
}

/// File dialogs used by the transcription window.
@MainActor
enum FilePanels {
    static let supportedTypes: [UTType] = [.audio, .movie, .audiovisualContent]

    static func chooseRecording() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Выберите аудио или видео"
        panel.prompt = "Расшифровать"
        panel.allowedContentTypes = supportedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func save(_ text: String, suggestedName: String) throws {
        let panel = NSSavePanel()
        panel.title = "Сохранить текст"
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

import SwiftUI

struct RadaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(app: delegate.app)
        } label: {
            MenuBarLabel(controller: delegate.app.controller)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let app = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { app.launch() }
    }

    /// Files opened via Finder («Открыть в программе → Rada») or dropped on the Dock icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        MainActor.assumeIsolated { app.openFileTranscription(url) }
    }
}

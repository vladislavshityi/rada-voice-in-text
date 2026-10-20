import AppKit
import SwiftUI

/// Hosts the settings UI in a regular window. While it is open Rada shows a
/// Dock icon so the window is easy to find; when it closes Rada returns to the menu bar.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let app: AppModel
    private let model = SettingsModel()
    private var window: NSWindow?
    private var permissionRefresh: Timer?

    init(app: AppModel) {
        self.app = app
    }

    func show(_ section: SettingsSection?) {
        if let section { model.selection = section }
        let window = window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Rada"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 720, height: 480)
        window.contentViewController = NSHostingController(rootView: SettingsView(app: app, model: model))
        window.setContentSize(CGSize(width: 820, height: 600))
        window.center()
        window.setFrameAutosaveName("RadaSettings")
        window.delegate = self
        return window
    }

    // Accessibility permission has no change notification, so poll while the window is active.
    func windowDidBecomeKey(_ notification: Notification) {
        app.permissions.refresh()
        permissionRefresh?.invalidate()
        permissionRefresh = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.app.permissions.refresh() }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        permissionRefresh?.invalidate()
        permissionRefresh = nil
    }

    func windowWillClose(_ notification: Notification) {
        model.stopRecordingShortcut(app: app)
        permissionRefresh?.invalidate()
        permissionRefresh = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

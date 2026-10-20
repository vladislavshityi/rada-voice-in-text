import AppKit

/// Rada lives in the menu bar. While one of its windows is open it shows a
/// Dock icon so the window is easy to find; when the last one closes, the icon goes away.
@MainActor
enum DockPresence {
    private static var openWindows = Set<ObjectIdentifier>()

    static func windowOpened(_ window: NSWindow) {
        openWindows.insert(ObjectIdentifier(window))
        NSApp.setActivationPolicy(.regular)
    }

    static func windowClosed(_ window: NSWindow) {
        openWindows.remove(ObjectIdentifier(window))
        if openWindows.isEmpty { NSApp.setActivationPolicy(.accessory) }
    }
}

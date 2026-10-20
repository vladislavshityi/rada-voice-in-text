import AppKit
import Observation
import RadaKit
import SwiftUI

/// What the floating indicator currently shows. Kept separate from the
/// controller's phase so the indicator can animate out with its last content.
@MainActor
@Observable
final class HUDModel {
    var phase: DictationController.Phase = .idle
    var isVisible = false
}

/// The floating recording indicator: a borderless, non-activating panel
/// just below the menu bar of the active screen. It never takes focus or clicks.
@MainActor
final class HUDController {
    private static let canvasSize = CGSize(width: 520, height: 150)

    private let model = HUDModel()
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    init(controller: DictationController) {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.canvasSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: HUDView(model: model, controller: controller))
    }

    func present(_ phase: DictationController.Phase) {
        guard phase != .idle else { return hide() }
        hideTask?.cancel()
        model.phase = phase
        if !panel.isVisible {
            position()
            panel.orderFrontRegardless()
        }
        model.isVisible = true
    }

    private func hide() {
        model.isVisible = false
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    /// Top center of the screen the user is working on, under the menu bar.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        panel.setFrameOrigin(CGPoint(
            x: visible.midX - Self.canvasSize.width / 2,
            y: visible.maxY - Self.canvasSize.height
        ))
    }
}

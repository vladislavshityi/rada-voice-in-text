import AppKit
import Carbon.HIToolbox

/// Delivers recognized text to the frontmost app.
///
/// The text is placed on the pasteboard and pasted with a synthesized ⌘V —
/// the one mechanism that works in native, Electron and web text fields alike.
/// The user's clipboard is restored afterwards. If pasting is impossible the
/// text is left on the clipboard and the caller tells the user.
@MainActor
public final class TextInserter {
    public enum Outcome: Equatable, Sendable {
        case inserted
        case copied(CopyReason)
    }

    public enum CopyReason: Equatable, Sendable {
        case clipboardMode
        case accessibilityMissing
        case secureInput
    }

    /// Time the target app gets to read the pasteboard before it is restored.
    private static let restoreDelay: Duration = .milliseconds(800)
    /// Marks our pasteboard write as transient so clipboard managers skip it.
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    public init() {}

    public func deliver(_ text: String, mode: InsertionMode, smartSpacing: Bool) -> Outcome {
        guard mode == .paste else {
            copyToClipboard(text)
            return .copied(.clipboardMode)
        }
        guard AXIsProcessTrusted() else {
            copyToClipboard(text)
            return .copied(.accessibilityMissing)
        }
        guard !IsSecureEventInputEnabled() else {
            copyToClipboard(text)
            return .copied(.secureInput)
        }
        paste(smartSpacing ? Self.spaced(text, after: FocusedTextContext.characterBeforeCaret()) : text)
        return .inserted
    }

    /// Adds a separating space when dictating right after a word.
    static func spaced(_ text: String, after previous: Character?) -> String {
        guard let previous, !previous.isWhitespace, !"([{«„\"'/—-".contains(previous) else { return text }
        guard let first = text.first, !",.;:!?…)»".contains(first) else { return text }
        return " " + text
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = Self.snapshot(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: Self.transientType)
        let ourChange = pasteboard.changeCount

        Self.postCommandV()

        Task {
            try? await Task.sleep(for: Self.restoreDelay)
            // Restore only if nobody copied anything in the meantime.
            guard pasteboard.changeCount == ourChange else { return }
            pasteboard.clearContents()
            if !saved.isEmpty { pasteboard.writeObjects(saved) }
        }
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            // Explicit flags: modifiers still held from the hotkey must not leak in.
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}

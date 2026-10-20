import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: a virtual key code plus modifier flags.
public struct Shortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt

    public init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers).rawValue
    }

    public static let optionSpace = Shortcut(keyCode: UInt32(kVK_Space), modifiers: .option)
    public static let escape = Shortcut(keyCode: UInt32(kVK_Escape), modifiers: [])

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    public var modifierFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// A global shortcut without modifiers would steal ordinary typing.
    public var isValidGlobalShortcut: Bool {
        !modifierFlags.isEmpty || Self.functionKeys.contains(Int(keyCode))
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifierFlags.contains(.command) { result |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { result |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { result |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    public var displayString: String {
        var parts = ""
        if modifierFlags.contains(.control) { parts += "⌃" }
        if modifierFlags.contains(.option) { parts += "⌥" }
        if modifierFlags.contains(.shift) { parts += "⇧" }
        if modifierFlags.contains(.command) { parts += "⌘" }
        return parts + keyName
    }

    /// Individual display tokens, e.g. ["⌥", "Space"], for key-cap rendering.
    public var displayTokens: [String] {
        var tokens: [String] = []
        if modifierFlags.contains(.control) { tokens.append("⌃") }
        if modifierFlags.contains(.option) { tokens.append("⌥") }
        if modifierFlags.contains(.shift) { tokens.append("⇧") }
        if modifierFlags.contains(.command) { tokens.append("⌘") }
        tokens.append(keyName)
        return tokens
    }

    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "Esc", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private var keyName: String {
        if let name = Self.specialKeyNames[Int(keyCode)] { return name }
        return Self.character(for: keyCode)?.uppercased() ?? "#\(keyCode)"
    }

    /// Resolves the character for a key code using the ASCII-capable layout
    /// so that shortcuts read the same regardless of the active input language.
    private static func character(for keyCode: UInt32) -> String? {
        guard
            let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data

        return layoutData.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeyState: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length)
        }
    }
}

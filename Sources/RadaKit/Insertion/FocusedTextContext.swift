@preconcurrency import ApplicationServices

/// Reads the character just before the caret in the focused text field via Accessibility.
enum FocusedTextContext {
    static func characterBeforeCaret() -> Character? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.25)

        guard
            let element: AXUIElement = attribute(kAXFocusedUIElementAttribute, of: system),
            let rangeValue: AXValue = attribute(kAXSelectedTextRangeAttribute, of: element)
        else { return nil }

        var selection = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &selection), selection.location > 0 else { return nil }

        var previous = CFRange(location: selection.location - 1, length: 1)
        guard let parameter = AXValueCreate(.cfRange, &previous) else { return nil }
        var result: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &result
        )
        guard status == .success, let string = result as? String else { return nil }
        return string.last
    }

    private static func attribute<T>(_ name: String, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}

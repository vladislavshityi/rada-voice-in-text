import Carbon.HIToolbox

/// System-wide shortcuts via Carbon `RegisterEventHotKey`.
///
/// This API needs no Accessibility permission, works while any app is active,
/// and only reacts to the exact registered combination.
@MainActor
public final class HotkeyCenter {
    public enum Action: UInt32, CaseIterable {
        case toggleDictation = 1
        case cancelDictation = 2
    }

    public var onAction: ((Action) -> Void)?

    private static let signature: OSType = 0x5241_4441 // 'RADA'
    private var registrations: [Action: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?

    public init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == HotkeyCenter.signature,
                      let action = Action(rawValue: hotKeyID.id)
                else { return OSStatus(eventNotHandledErr) }
                let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { center.onAction?(action) }
                return noErr
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler
        )
    }

    /// Registers `shortcut`; returns `false` if another app already owns it.
    @discardableResult
    public func register(_ shortcut: Shortcut, for action: Action) -> Bool {
        unregister(action)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: action.rawValue),
            GetApplicationEventTarget(), 0, &reference
        )
        guard status == noErr, let reference else { return false }
        registrations[action] = reference
        return true
    }

    public func unregister(_ action: Action) {
        guard let reference = registrations.removeValue(forKey: action) else { return }
        UnregisterEventHotKey(reference)
    }

    public func isRegistered(_ action: Action) -> Bool {
        registrations[action] != nil
    }
}

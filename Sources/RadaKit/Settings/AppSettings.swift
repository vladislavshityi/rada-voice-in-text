import Foundation
import Observation

/// User preferences persisted in `UserDefaults`.
@MainActor
@Observable
public final class AppSettings {
    public var shortcut: Shortcut { didSet { store(shortcut, for: .shortcut) } }
    public var engine: EngineKind { didSet { store(engine, for: .engine) } }
    public var language: RecognitionLanguage { didSet { store(language, for: .language) } }
    public var insertionMode: InsertionMode { didSet { store(insertionMode, for: .insertionMode) } }
    public var voiceCommandsEnabled: Bool { didSet { store(voiceCommandsEnabled, for: .voiceCommands) } }
    public var smartSpacingEnabled: Bool { didSet { store(smartSpacingEnabled, for: .smartSpacing) } }
    public var soundsEnabled: Bool { didSet { store(soundsEnabled, for: .sounds) } }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcut = Self.load(.shortcut, from: defaults) ?? .optionSpace
        engine = Self.load(.engine, from: defaults) ?? .whisper
        language = Self.load(.language, from: defaults) ?? .russian
        insertionMode = Self.load(.insertionMode, from: defaults) ?? .paste
        voiceCommandsEnabled = Self.load(.voiceCommands, from: defaults) ?? true
        smartSpacingEnabled = Self.load(.smartSpacing, from: defaults) ?? true
        soundsEnabled = Self.load(.sounds, from: defaults) ?? true
    }

    /// Restores defaults and removes every stored preference.
    public func reset() {
        Key.allCases.forEach { defaults.removeObject(forKey: $0.rawValue) }
        shortcut = .optionSpace
        engine = .whisper
        language = .russian
        insertionMode = .paste
        voiceCommandsEnabled = true
        smartSpacingEnabled = true
        soundsEnabled = true
    }

    private enum Key: String, CaseIterable {
        case shortcut, engine, language, insertionMode, voiceCommands, smartSpacing, sounds
    }

    private func store<Value: Encodable>(_ value: Value, for key: Key) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key.rawValue)
    }

    private static func load<Value: Decodable>(_ key: Key, from defaults: UserDefaults) -> Value? {
        defaults.data(forKey: key.rawValue).flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }
}

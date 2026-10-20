import Foundation

/// Hands out the engine chosen in settings. Dictation and file transcription
/// share one Whisper instance, so the model is loaded into memory only once.
@MainActor
public final class EngineProvider {
    private let settings: AppSettings
    private let modelInstaller: ModelInstaller
    private var whisperEngine: WhisperEngine?

    public init(settings: AppSettings, modelInstaller: ModelInstaller) {
        self.settings = settings
        self.modelInstaller = modelInstaller
    }

    public func engine() throws(DictationIssue) -> any TranscriptionEngine {
        switch settings.engine {
        case .whisper:
            guard modelInstaller.isInstalled else { throw .modelMissing }
            if let whisperEngine { return whisperEngine }
            let engine = WhisperEngine(modelURL: modelInstaller.model.localURL, vadModelURL: AppPaths.bundledVADModel)
            whisperEngine = engine
            return engine
        case .appleDictation:
            guard #available(macOS 26, *) else { throw .engineUnavailable }
            return AppleDictationEngine()
        }
    }

    /// Releases the Whisper model, e.g. after the model file was deleted.
    public func release() {
        whisperEngine = nil
    }
}

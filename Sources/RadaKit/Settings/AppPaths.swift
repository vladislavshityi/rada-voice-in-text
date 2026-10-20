import Foundation

/// Locations of everything Rada stores on disk. All data stays in the user's Library.
public enum AppPaths {
    public static var applicationSupport: URL {
        URL.applicationSupportDirectory.appending(path: "Rada", directoryHint: .isDirectory)
    }

    public static var models: URL {
        applicationSupport.appending(path: "Models", directoryHint: .isDirectory)
    }

    public static var dictionary: URL {
        applicationSupport.appending(path: "dictionary.json")
    }

    /// Silero VAD model shipped inside the app bundle.
    public static var bundledVADModel: URL? {
        Bundle.main.url(forResource: "ggml-silero-vad", withExtension: "bin")
    }

    static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

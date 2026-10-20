import Foundation

/// The Whisper model Rada uses, pinned by checksum.
public struct WhisperModel: Sendable {
    public let name: String
    public let fileName: String
    public let downloadURL: URL
    public let sha256: String
    public let byteCount: Int64

    /// Large v3 Turbo, 5-bit quantized: best quality-to-speed ratio for Russian on Apple Silicon.
    public static let largeV3Turbo = WhisperModel(
        name: "Whisper Large v3 Turbo",
        fileName: "ggml-large-v3-turbo-q5_0.bin",
        downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!,
        sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
        byteCount: 574_041_195
    )

    public var localURL: URL { AppPaths.models.appending(path: fileName) }

    public var isInstalled: Bool { FileManager.default.fileExists(atPath: localURL.path) }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

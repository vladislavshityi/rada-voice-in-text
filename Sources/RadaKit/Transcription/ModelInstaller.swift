import CryptoKit
import Foundation
import Observation

/// Downloads, verifies and removes the Whisper model.
///
/// This is the only place where Rada touches the network, and only after the
/// user presses «Загрузить». The file is checked against a pinned SHA-256.
@MainActor
@Observable
public final class ModelInstaller {
    public enum State: Equatable {
        case notInstalled
        case downloading(progress: Double)
        case verifying
        case installed
        case failed(String)
    }

    public let model: WhisperModel
    public private(set) var state: State

    private var downloadTask: Task<Void, Never>?

    public init(model: WhisperModel = .largeV3Turbo) {
        self.model = model
        state = model.isInstalled ? .installed : .notInstalled
    }

    public var isInstalled: Bool { state == .installed }

    public func download() {
        guard downloadTask == nil else { return }
        state = .downloading(progress: 0)
        downloadTask = Task {
            defer { downloadTask = nil }
            do {
                let temporary = try await fetch()
                state = .verifying
                try await Self.verify(temporary, sha256: model.sha256)
                try AppPaths.ensureDirectory(AppPaths.models)
                try? FileManager.default.removeItem(at: model.localURL)
                try FileManager.default.moveItem(at: temporary, to: model.localURL)
                state = .installed
            } catch is CancellationError {
                state = .notInstalled
            } catch let error as URLError where error.code == .cancelled {
                state = .notInstalled
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    public func cancelDownload() {
        downloadTask?.cancel()
    }

    public func remove() {
        try? FileManager.default.removeItem(at: model.localURL)
        state = .notInstalled
    }

    private func fetch() async throws -> URL {
        let downloader = FileDownloader { [weak self] progress in
            Task { @MainActor in
                guard let self, case .downloading = self.state else { return }
                self.state = .downloading(progress: progress)
            }
        }
        return try await downloader.download(model.downloadURL)
    }

    private nonisolated static func verify(_ file: URL, sha256 expected: String) async throws {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let data = try handle.read(upToCount: 4 << 20), !data.isEmpty {
                hasher.update(data: data)
            }
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == expected else {
                try? FileManager.default.removeItem(at: file)
                throw InstallError.checksumMismatch
            }
        }.value
    }

    enum InstallError: LocalizedError {
        case checksumMismatch

        var errorDescription: String? { "Файл повреждён: контрольная сумма не совпала." }
    }
}

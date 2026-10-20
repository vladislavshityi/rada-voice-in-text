import Foundation
import Synchronization

/// One-shot file download with progress reporting and cancellation.
final class FileDownloader: NSObject, URLSessionDownloadDelegate, Sendable {
    private struct Pending {
        var continuation: CheckedContinuation<URL, Error>?
        var task: URLSessionDownloadTask?
        var file: URL?
        var reportedProgress: Double = 0
    }

    private let onProgress: @Sendable (Double) -> Void
    private let pending = Mutex(Pending())

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func download(_ url: URL) async throws -> URL {
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.downloadTask(with: url)
                pending.withLock {
                    $0.continuation = continuation
                    $0.task = task
                }
                task.resume()
            }
        } onCancel: {
            pending.withLock { $0.task }?.cancel()
        }
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        // Report in 0.5 % steps: enough for a smooth bar without flooding the UI.
        let shouldReport = pending.withLock { state in
            guard progress - state.reportedProgress >= 0.005 else { return false }
            state.reportedProgress = progress
            return true
        }
        if shouldReport { onProgress(progress) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The system deletes `location` when this method returns, so move it now.
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { return }
        let destination = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        if (try? FileManager.default.moveItem(at: location, to: destination)) != nil {
            pending.withLock { $0.file = destination }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (continuation, file) = pending.withLock { state in
            defer { state.continuation = nil }
            return (state.continuation, state.file)
        }
        if let error {
            continuation?.resume(throwing: error)
        } else if let file {
            continuation?.resume(returning: file)
        } else {
            continuation?.resume(throwing: URLError(.badServerResponse))
        }
    }
}
